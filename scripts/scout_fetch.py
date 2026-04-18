#!/usr/bin/env python3
"""
scout_fetch.py — fetch Instagram reels metadata with view counts.

gallery-dl already handles the hard parts (session cookies, Instagram's
private-API dance, rate limiting), but its Instagram extractor discards
`play_count` when building the post dict. We need view counts to calculate
the baseline / 5x outlier threshold that scout is built around.

This wrapper monkey-patches gallery-dl's two post parsers (_parse_post_rest
for the mobile/private API, _parse_post_graphql for the web GraphQL fallback)
to preserve play_count before the dict is frozen. Then it runs gallery-dl's
DataJob programmatically, reads the collected posts, and emits one JSONL
record per reel on stdout — the format scout_reels.sh already knows how to
parse.

Intentional fragility: if gallery-dl refactors those method names, this
wrapper breaks. The fix is a field-name update, not a rewrite — that's the
deliberate tradeoff we took over a from-scratch Instagram GraphQL scraper.

Usage:
  python scout_fetch.py <handle> [--limit N] [--cookies-from-browser B | --cookies FILE]

Exits:
  0  success (JSONL written to stdout)
  3  dependency missing (gallery-dl not installed / import failed)
  4  fetch failed or no data returned (generic — stderr has detail)
  8  authentication failed (login required — bubbled up as distinct code
     via the exception message; scout_reels.sh matches on stderr patterns,
     so we just print the raw exception and let the shell classify)
"""
import argparse
import json
import sys
from datetime import datetime, timezone

try:
    from gallery_dl.extractor import instagram as ig_module
    from gallery_dl import job, config
except ImportError as e:
    print(f"gallery-dl import failed: {e}", file=sys.stderr)
    print("Install with: pip install --user gallery-dl", file=sys.stderr)
    sys.exit(3)


# ---- Monkey-patch: preserve play_count from the raw post dict ----

_orig_parse_rest = ig_module.InstagramExtractor._parse_post_rest
_orig_parse_graphql = ig_module.InstagramExtractor._parse_post_graphql


def _patched_rest(self, post):
    data = _orig_parse_rest(self, post)
    # Private/mobile API — the reels endpoint uses this path
    pc = (post.get("play_count")
          or post.get("ig_play_count")
          or post.get("view_count")
          or 0)
    try:
        data["play_count"] = int(pc)
    except (TypeError, ValueError):
        data["play_count"] = 0
    return data


def _patched_graphql(self, post):
    data = _orig_parse_graphql(self, post)
    # Web GraphQL — fallback when REST isn't available
    pc = (post.get("video_play_count")
          or post.get("video_view_count")
          or 0)
    try:
        data["play_count"] = int(pc)
    except (TypeError, ValueError):
        data["play_count"] = 0
    return data


ig_module.InstagramExtractor._parse_post_rest = _patched_rest
ig_module.InstagramExtractor._parse_post_graphql = _patched_graphql


# ---- Main ----

def parse_args():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    p.add_argument("handle", help="Instagram handle (no @)")
    p.add_argument("--limit", type=int, default=30,
                   help="Max reels to fetch (default: 30)")
    p.add_argument("--cookies-from-browser",
                   help="Browser to load cookies from (chrome/firefox/edge/opera/brave)")
    p.add_argument("--cookies",
                   help="Path to a Netscape-format cookies.txt file (fallback)")
    return p.parse_args()


def to_epoch(val):
    """gallery-dl emits `date` as a datetime; normalize to epoch seconds."""
    if val is None:
        return 0
    if isinstance(val, (int, float)):
        return int(val)
    if isinstance(val, datetime):
        if val.tzinfo is None:
            val = val.replace(tzinfo=timezone.utc)
        return int(val.timestamp())
    if isinstance(val, str):
        # gallery-dl occasionally emits strings like "2025-12-01 14:33:21"
        for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S"):
            try:
                dt = datetime.strptime(val, fmt).replace(tzinfo=timezone.utc)
                return int(dt.timestamp())
            except ValueError:
                continue
    return 0


def configure_gallery_dl(args):
    config.load()
    # Limit to the first N reels; gallery-dl uses 1-indexed ranges.
    config.set((), "range", f"1-{args.limit}")
    # Polite rate limiting — mirrors scout_reels.sh's --sleep-requests 1 for yt-dlp.
    config.set(("extractor",), "sleep-request", 1.0)
    # Force video-only reels (should already be the case for /reels/ URLs, but
    # defensive in case Instagram mixes photo carousels into the endpoint).
    config.set(("extractor", "instagram"), "videos", True)

    # Force jsonl=false; otherwise DataJob.out() tries to write to self.file
    # which we set to None (to suppress the pretty-JSON dump), causing a
    # NoneType.write crash if a stray user config enables jsonl.
    config.set(("output",), "jsonl", False)

    if args.cookies_from_browser:
        # gallery-dl expects a list: [browser, profile, keyring, container]
        # We only pass browser; profile is wired via config file if the user
        # needs it. Keep the simple case simple.
        config.set(("extractor",),
                   "cookies-from-browser", [args.cookies_from_browser])
    elif args.cookies:
        config.set(("extractor",), "cookies", args.cookies)
    # else: no auth configured; Instagram will 401 and we bubble up the error


def emit(post):
    """Convert gallery-dl post kwdict → scout JSONL format."""
    shortcode = post.get("post_shortcode") or post.get("shortcode") or ""
    url = f"https://www.instagram.com/reel/{shortcode}/" if shortcode else ""
    views = post.get("play_count", 0) or 0
    date = post.get("date") or post.get("post_date")
    caption = post.get("description") or ""
    sys.stdout.write(json.dumps({
        "id": shortcode,
        "url": url,
        "view_count": int(views),
        "timestamp": to_epoch(date),
        "title": caption.replace("\n", " ")[:140],
    }) + "\n")


def main():
    args = parse_args()
    url = f"https://www.instagram.com/{args.handle}/reels/"
    configure_gallery_dl(args)

    # Suppress gallery-dl's JSON dump to stdout; we'll emit our own JSONL after.
    # Passing file=None tells DataJob not to flush its pretty array at the end.
    j = job.DataJob(url, file=None)

    # DataJob.run() catches Exception internally and stores the error in
    # j.exception (returning 0 regardless). The only things it re-raises are
    # BaseException (KeyboardInterrupt, SystemExit). So we don't need a
    # GalleryDLException handler around j.run() — we read j.exception after.
    try:
        j.run()
    except KeyboardInterrupt:
        sys.exit(130)

    if j.exception is not None:
        # Check for auth errors specifically so we exit 8 (the exit code
        # scout_reels.sh understands as "not logged in") instead of the
        # generic 4. gallery-dl sets code=16 on AuthenticationError and
        # AuthorizationError — see gallery_dl/exception.py.
        code = getattr(j.exception, "code", None)
        msg = str(j.exception)
        print(f"gallery-dl: {msg}", file=sys.stderr)
        if code == 16 or "401" in msg or "Login required" in msg:
            sys.exit(8)
        sys.exit(4)

    posts = j.data_post or []
    if not posts:
        print("gallery-dl returned no posts", file=sys.stderr)
        sys.exit(4)

    for post in posts:
        try:
            emit(post)
        except Exception as e:
            # Don't let one weird post kill the whole batch; log and skip.
            print(f"skipping post ({e})", file=sys.stderr)
            continue


if __name__ == "__main__":
    main()
