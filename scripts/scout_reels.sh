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
for cmd in yt-dlp; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: missing required tool: $cmd" >&2
        exit 3
    fi
done

PY="python3"
if ! command -v python3 &>/dev/null; then
    if command -v python &>/dev/null; then
        PY="python"
    else
        echo "Error: missing required tool: python" >&2
        exit 3
    fi
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
            chrome|chromium|edge|firefox|opera|brave|vivaldi|safari|whale)
                SPEC="$BROWSER"
                if [ -n "$PROFILE" ]; then
                    SPEC="${BROWSER}:${PROFILE}"
                fi
                AUTH_ARGS=(--cookies-from-browser "$SPEC")
                AUTH_MODE="browser:$BROWSER"
                ;;
            *)
                echo "Error: invalid BROWSER value in $CONF: $BROWSER" >&2
                echo "Supported: chrome, chromium, edge, firefox, opera, brave, vivaldi, safari, whale" >&2
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
URL="https://www.instagram.com/${HANDLE}/reels/"

if [ "${CACHE_HIT:-0}" != "1" ]; then
    echo "Scanning @${HANDLE} (last ${DAYS} days, auth: ${AUTH_MODE})..." >&2

    STDERR_FILE=$(mktemp 2>/dev/null || echo "/tmp/scout_err_$$")
    set +e
    RAW=$(yt-dlp \
        "${AUTH_ARGS[@]}" \
        --flat-playlist \
        -j \
        --playlist-end 30 \
        --sleep-requests 1 \
        --no-warnings \
        "$URL" 2>"$STDERR_FILE")
    RC=$?
    set -e
    STDERR=$(cat "$STDERR_FILE" 2>/dev/null || echo "")
    rm -f "$STDERR_FILE"

    if [ $RC -ne 0 ] || [ -z "$RAW" ]; then
        # Error classification. Patterns based on yt-dlp stderr behavior; imperfect
        # but good enough to route the user to the right fix.
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
        # Check rate-limit BEFORE "login required" — a 429 may include auth-ish text
        # in fallback messages, and misrouting it to "log in again" would make the
        # problem worse.
        if echo "$STDERR" | grep -qiE "HTTP Error 429|rate.?limit|please wait a few minutes|too many requests"; then
            echo "$STDERR" >&2
            echo "---" >&2
            echo "Instagram rate-limited us. Wait 10-30 minutes before retrying." >&2
            exit 9
        fi
        if echo "$STDERR" | grep -qiE "login required|not available.*logged|restricted.*login|requires.*authentication|401|empty media response"; then
            echo "$STDERR" >&2
            echo "---" >&2
            echo "Not logged in to Instagram in $BROWSER (or session expired)." >&2
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
printf '%s\n' "$RAW" | "$PY" - "$HANDLE" "$DAYS" <<'PYEOF'
import json, sys, time

handle = sys.argv[1]
days = int(sys.argv[2])
cutoff = time.time() - days * 86400

reels = []
for line in sys.stdin:
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
PYEOF
