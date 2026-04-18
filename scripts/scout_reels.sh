#!/bin/bash
# scout_reels.sh — find viral outlier reels for an Instagram handle
# Usage: bash scout_reels.sh <handle> [days]
#
# Reads browser preference from ~/reel-engine/scout.conf (key: BROWSER=chrome|firefox|edge|opera|brave).
# Uses yt-dlp --cookies-from-browser to auth with Instagram. Falls back to ~/reel-engine/cookies.txt if present.
# Caches successful scans per-handle for 2h to reduce rate-limit risk.
#
# Exit codes:
#   0  success (report printed, outliers may or may not exist)
#   2  bad input
#   3  missing dependency
#   4  fetch failed (generic — see stderr for detail)
#   5  no browser configured (caller should ask user and write scout.conf)
#   6  cookie DB locked (browser is open — caller asks user to close it)
#   7  cookie decrypt failed (Chrome app-bound encryption — caller suggests fallback)
#   8  not logged in / session expired (caller asks user to log in)
#   9  rate-limited by Instagram (caller waits)
#  10  invalid browser value in scout.conf

set -euo pipefail

HANDLE="${1:-}"
DAYS="${2:-30}"

if [ -z "$HANDLE" ]; then
    echo "Usage: bash scout_reels.sh <handle> [days]" >&2
    exit 2
fi

HANDLE="${HANDLE#@}"

if [[ ! "$HANDLE" =~ ^[A-Za-z0-9._]{1,30}$ ]]; then
    echo "Error: invalid Instagram handle: $HANDLE" >&2
    exit 2
fi

if [[ ! "$DAYS" =~ ^[0-9]+$ ]] || [ "$DAYS" -eq 0 ]; then
    echo "Error: days must be a positive integer, got: $DAYS" >&2
    exit 2
fi

# ---- Dependencies ----
# Pick a working Python interpreter. On Windows, `python3` often resolves to
# the Microsoft Store stub — it's on PATH but just prints an install nag and
# exits. So we test each candidate by actually running `import sys`.
PY=""
for candidate in python3 python py; do
    if command -v "$candidate" &>/dev/null && \
       "$candidate" -c "import sys; sys.exit(0)" &>/dev/null; then
        PY="$candidate"
        break
    fi
done
if [ -z "$PY" ]; then
    echo "Error: no working Python interpreter found on PATH." >&2
    exit 3
fi

# gallery-dl is invoked in-process by scout_fetch.py. We verify by import so
# a broken install fails here cleanly instead of buried inside Python later.
if ! "$PY" -c "import gallery_dl" 2>/dev/null; then
    echo "Error: gallery-dl is not installed for $PY." >&2
    echo "  Run: $PY -m pip install --user gallery-dl" >&2
    exit 3
fi

# ---- Paths ----
REEL_HOME="$HOME/reel-engine"
CONF="$REEL_HOME/scout.conf"
COOKIES_TXT="$REEL_HOME/cookies.txt"
CACHE_DIR="$REEL_HOME/.scout_cache"
mkdir -p "$CACHE_DIR"

# ---- Cache check (2h TTL) ----
CACHE_FILE="$CACHE_DIR/${HANDLE}.json"
if [ -f "$CACHE_FILE" ]; then
    NOW=$(date +%s)
    MTIME=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
    AGE=$((NOW - MTIME))
    if [ "$AGE" -lt 7200 ]; then
        echo "(using cached scan from $((AGE / 60)) min ago — cache expires in $(( (7200 - AGE) / 60 )) min)" >&2
        RAW=$(cat "$CACHE_FILE")
        CACHE_HIT=1
    fi
fi

# ---- Resolve auth method ----
AUTH_ARGS=()
AUTH_MODE="none"

if [ "${CACHE_HIT:-0}" != "1" ]; then
    BROWSER=""
    PROFILE=""
    COOKIES_FILE=""
    if [ -f "$CONF" ]; then
        # Parse scout.conf safely — do NOT `source` it (would execute arbitrary shell).
        # Only accept KEY=VALUE lines with a whitelisted key set and safe value chars.
        while IFS= read -r line || [ -n "$line" ]; do
            # Strip comments and whitespace
            line="${line%%#*}"
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [ -z "$line" ] && continue
            case "$line" in
                BROWSER=*)
                    val="${line#BROWSER=}"
                    val="${val%\"}"; val="${val#\"}"
                    val="${val%\'}"; val="${val#\'}"
                    if [[ "$val" =~ ^[A-Za-z]+$ ]]; then BROWSER="$val"; fi
                    ;;
                PROFILE=*)
                    val="${line#PROFILE=}"
                    val="${val%\"}"; val="${val#\"}"
                    val="${val%\'}"; val="${val#\'}"
                    if [[ "$val" =~ ^[A-Za-z0-9._\ -]+$ ]]; then PROFILE="$val"; fi
                    ;;
            esac
        done < "$CONF"
    fi

    if [ -n "$BROWSER" ]; then
        case "$BROWSER" in
            chrome|chromium|edge|firefox|opera|brave|vivaldi|safari)
                SPEC="$BROWSER"
                if [ -n "$PROFILE" ]; then
                    SPEC="${BROWSER}:${PROFILE}"
                fi
                AUTH_ARGS=(--cookies-from-browser "$SPEC")
                AUTH_MODE="browser:$BROWSER"
                ;;
            *)
                echo "Error: invalid BROWSER value in $CONF: $BROWSER" >&2
                echo "Supported: chrome, chromium, edge, firefox, opera, brave, vivaldi, safari" >&2
                exit 10
                ;;
        esac
    elif [ -f "$COOKIES_TXT" ]; then
        AUTH_ARGS=(--cookies "$COOKIES_TXT")
        AUTH_MODE="cookies-txt"
    else
        echo "Error: no browser configured and no cookies.txt fallback found." >&2
        echo "Expected: $CONF with BROWSER=<name>, or $COOKIES_TXT" >&2
        exit 5
    fi
fi

# ---- Fetch ----
# We call scout_fetch.py (Python wrapper around gallery-dl) instead of yt-dlp
# directly, because yt-dlp's Instagram user/reels extractor is currently broken
# upstream ("Unable to extract data"). gallery-dl's extractor is maintained but
# drops play_count from its output dict — the wrapper monkey-patches that.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FETCH_PY="$SCRIPT_DIR/scout_fetch.py"

if [ ! -f "$FETCH_PY" ]; then
    echo "Error: scout_fetch.py not found next to scout_reels.sh ($FETCH_PY)" >&2
    exit 3
fi

if [ "${CACHE_HIT:-0}" != "1" ]; then
    echo "Scanning @${HANDLE} (last ${DAYS} days, auth: ${AUTH_MODE})..." >&2

    STDERR_FILE=$(mktemp 2>/dev/null || echo "/tmp/scout_err_$$")
    set +e
    RAW=$("$PY" "$FETCH_PY" "$HANDLE" --limit 30 "${AUTH_ARGS[@]}" 2>"$STDERR_FILE")
    RC=$?
    set -e
    STDERR=$(cat "$STDERR_FILE" 2>/dev/null || echo "")
    rm -f "$STDERR_FILE"

    if [ $RC -ne 0 ] || [ -z "$RAW" ]; then
        # Error classification. gallery-dl and yt-dlp share the browser-cookie
        # extraction path (both delegate to yt-dlp's cookies module), so the
        # DB-locked / ABE patterns are effectively identical. Instagram API
        # patterns are gallery-dl-specific.
        if echo "$STDERR" | grep -qiE "could not copy.*cookie database|database is locked|locked.*cookie|PermissionError.*Cookies"; then
            echo "$STDERR" >&2
            echo "---" >&2
            echo "Cookie database is locked. Close $BROWSER completely (all windows + background) and retry." >&2
            exit 6
        fi
        if echo "$STDERR" | grep -qiE "failed to decrypt|DPAPI|unable to decrypt|app.?bound encryption"; then
            echo "$STDERR" >&2
            echo "---" >&2
            echo "Chrome app-bound encryption blocked cookie decryption." >&2
            exit 7
        fi
        # Check rate-limit BEFORE "login required" — a 429 may include auth-ish
        # text in fallback messages, and misrouting it to "log in again" makes
        # it worse.
        if echo "$STDERR" | grep -qiE "HTTP Error 429|429 Too Many Requests|rate.?limit|please wait a few minutes|too many requests"; then
            echo "$STDERR" >&2
            echo "---" >&2
            echo "Instagram rate-limited us. Wait 10-30 minutes before retrying." >&2
            exit 9
        fi
        if echo "$STDERR" | grep -qiE "401 Unauthorized|login required|not available.*logged|restricted.*login|requires.*authentication|LoginRequired"; then
            echo "$STDERR" >&2
            echo "---" >&2
            echo "Not logged in to Instagram in ${BROWSER:-<no browser configured>} (or session expired)." >&2
            exit 8
        fi
        # Generic failure
        echo "$STDERR" >&2
        echo "---" >&2
        echo "Error: could not fetch reels for @${HANDLE}." >&2
        exit 4
    fi

    # Save cache
    printf '%s' "$RAW" > "$CACHE_FILE"
fi

# ---- Parse + report ----
# NOTE: `python - <<EOF` consumes stdin for the script body, so we can't also
# pipe data in on stdin — sys.stdin would be EOF. Pass the JSONL via a temp
# file and read the path from argv instead.
RAW_FILE=$(mktemp 2>/dev/null || echo "/tmp/scout_raw_$$")
printf '%s\n' "$RAW" > "$RAW_FILE"
trap 'rm -f "$RAW_FILE"' EXIT

"$PY" - "$HANDLE" "$DAYS" "$RAW_FILE" <<'PYEOF'
import json, sys, time
# Windows default terminal is cp1252 — captions contain emoji/quotes that blow
# up on encode. Reconfigure stdout to UTF-8 (with replace as last-ditch).
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

handle = sys.argv[1]
days = int(sys.argv[2])
raw_path = sys.argv[3]
cutoff = time.time() - days * 86400

reels = []
with open(raw_path, "r", encoding="utf-8") as f:
  for line in f:
    line = line.strip()
    if not line:
        continue
    try:
        d = json.loads(line)
    except json.JSONDecodeError:
        continue
    views = d.get("view_count")
    ts = d.get("timestamp") or 0
    if views is None:
        continue
    # Missing timestamp = can't verify it's in the window. Drop it rather than
    # silently pollute "last N days" reports with ancient reels.
    if not ts or ts < cutoff:
        continue
    rid = d.get("id") or ""
    url = d.get("url") or d.get("webpage_url") or (
        f"https://www.instagram.com/reel/{rid}/" if rid else ""
    )
    title = (d.get("title") or d.get("description") or "").strip().replace("\n", " ")
    reels.append({
        "id": rid, "url": url, "views": int(views), "ts": ts,
        "title": title[:140],
    })

def report(lines): print("\n".join(lines))

if not reels:
    report([
        "", f"SCOUT REPORT — @{handle}", "=" * 50,
        f"No reels with view counts found in the last {days} days.",
        "Possible causes:",
        "  - Creator hasn't posted recent reels",
        "  - Instagram withheld view counts in the grid",
        "  - Private account (scout only works on public profiles)",
        "",
    ])
    sys.exit(0)

if len(reels) < 3:
    report([
        "", f"SCOUT REPORT — @{handle}", "=" * 50,
        f"Only {len(reels)} reels in the last {days} days — not enough for a baseline.",
        "", "RECENT:",
    ])
    for r in sorted(reels, key=lambda x: -x["views"]):
        print(f'  {r["views"]:>8} views — {r["url"]}')
        if r["title"]: print(f'           "{r["title"][:90]}"')
    print()
    sys.exit(0)

views_sorted = sorted(r["views"] for r in reels)
trim = max(1, len(views_sorted) // 10)
keep = views_sorted[:-trim]
baseline = sum(keep) // len(keep) if keep else 0
threshold = baseline * 5

outliers = [r for r in reels if r["views"] >= threshold and baseline > 0]
outliers.sort(key=lambda x: -x["views"])
close = [r for r in reels if baseline * 4 <= r["views"] < threshold]
close.sort(key=lambda x: -x["views"])

lines = [
    "", f"SCOUT REPORT — @{handle}", "=" * 50,
    f"Scanned:    {len(reels)} reels (last {days} days)",
    f"Baseline:   {baseline:,} views (mean after trimming top {trim})",
    f"Threshold:  {threshold:,} views (5x baseline)", "",
]
if outliers:
    lines.append(f"OUTLIERS ({len(outliers)}):")
    for i, r in enumerate(outliers, 1):
        mult = r["views"] / baseline if baseline else 0
        lines.append(f'  {i}. {r["views"]:>10,} views  ({mult:.1f}x)')
        lines.append(f'     {r["url"]}')
        if r["title"]:
            lines.append(f'     "{r["title"][:100]}"')
        lines.append("")
else:
    lines.append("OUTLIERS: none this window.")
    lines.append("")
if close:
    lines.append(f"CLOSE BUT UNDER (4-5x):")
    for r in close[:3]:
        mult = r["views"] / baseline if baseline else 0
        lines.append(f'  {r["views"]:>10,} views  ({mult:.1f}x)  {r["url"]}')
    lines.append("")
lines.append("=" * 50)
report(lines)

# ---- Append to daily outlier journal ----
# One markdown file per day under ~/reel-engine/outliers/YYYY-MM-DD.md.
# Deduplicates by URL within the day, so re-running the same handle doesn't
# bloat the log. Only the "real" outliers (5x+) are journaled — close-but-
# under reels are noise at this scale.
if outliers:
    import os, re
    home = os.path.expanduser("~")
    journal_dir = os.path.join(home, "reel-engine", "outliers")
    os.makedirs(journal_dir, exist_ok=True)
    today = time.strftime("%Y-%m-%d")
    journal_path = os.path.join(journal_dir, f"{today}.md")

    # Read existing URLs to avoid duplicates
    existing_urls = set()
    if os.path.exists(journal_path):
        with open(journal_path, "r", encoding="utf-8") as f:
            existing_urls = set(re.findall(r"https?://[^\s\)]+", f.read()))

    new_outliers = [r for r in outliers if r["url"] not in existing_urls]
    if new_outliers:
        is_new_file = not os.path.exists(journal_path)
        with open(journal_path, "a", encoding="utf-8") as f:
            if is_new_file:
                f.write(f"# Outliers — {today}\n\n")
                f.write("Viral outliers (5x+ baseline) found during scouts today.\n\n")
            f.write(f"## @{handle}\n\n")
            f.write(f"_Scanned {len(reels)} reels (last {days} days). "
                    f"Baseline: {baseline:,} views. Threshold: {threshold:,}._\n\n")
            for r in new_outliers:
                mult = r["views"] / baseline if baseline else 0
                f.write(f"- **{r['views']:,} views** ({mult:.1f}x) — {r['url']}\n")
                if r["title"]:
                    # Escape markdown chars minimally
                    t = r["title"].replace("*", r"\*").replace("_", r"\_")
                    f.write(f"  > {t[:140]}\n")
            f.write("\n")
        print(f"\n[journaled {len(new_outliers)} outlier(s) to {journal_path}]",
              file=sys.stderr)
PYEOF
