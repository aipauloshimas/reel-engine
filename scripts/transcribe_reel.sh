#!/bin/bash
# transcribe_reel.sh — download, transcribe, and rename an Instagram reel
# Usage: bash transcribe_reel.sh "<URL>" [output_dir]
#
# output_dir defaults to the legacy ~/reel-engine/Reels/Videos. The reel-grab
# skill passes the session folder (the conversation's working directory) so
# each session keeps its own reels.

set -euo pipefail

URL="${1:-}"
OUT_DIR="${2:-}"
LEGACY_DIR="${HOME}/reel-engine/Reels/Videos"
VIDEOS_DIR="${OUT_DIR:-$LEGACY_DIR}"

if [ -z "$URL" ]; then
    echo "Usage: bash transcribe_reel.sh <instagram_url> [output_dir]" >&2
    exit 1
fi

# Validate URL — only Instagram host, only https, only reel/post/tv paths.
# Path allowlist prevents passing profile URLs, login pages, or stories.
# Host anchor prevents lookalikes like instagram.com.evil.com.
if [[ ! "$URL" =~ ^https://(www\.)?instagram\.com/(reel|reels|p|tv)/[A-Za-z0-9_-]+/?(\?.*)?$ ]]; then
    echo "Error: URL must be an Instagram reel, post, or TV link:" >&2
    echo "  https://www.instagram.com/reel/XXXXX/" >&2
    echo "  https://www.instagram.com/p/XXXXX/" >&2
    echo "Got: $URL" >&2
    exit 1
fi

# On Windows (Git Bash / MSYS), try to find ffmpeg from WinGet if not in PATH
if [[ "${OSTYPE:-}" == "msys" || "${OSTYPE:-}" == "cygwin" ]]; then
    if ! command -v ffmpeg &>/dev/null; then
        # Restrict to the Gyan.FFmpeg package installed by `winget install Gyan.FFmpeg`.
        # Broader globs can promote an unrelated packaged ffmpeg.exe to PATH head.
        WINGET_FFMPEG=$(find "/c/Users/${USERNAME:-$USER}/AppData/Local/Microsoft/WinGet/Packages" \
            -path "*Gyan.FFmpeg*" -name "ffmpeg.exe" 2>/dev/null | head -1 || true)
        if [ -n "$WINGET_FFMPEG" ]; then
            # Append, not prepend — don't let a discovered binary shadow the user's own PATH.
            export PATH="$PATH:$(dirname "$WINGET_FFMPEG")"
        fi
    fi
fi

# Verify required dependencies
missing=()
for cmd in yt-dlp whisper ffmpeg; do
    if ! command -v "$cmd" &>/dev/null; then
        missing+=("$cmd")
    fi
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo "Error: missing required tools: ${missing[*]}" >&2
    echo "Ask Claude Code to re-run the reel-engine install to fix this." >&2
    exit 1
fi

mkdir -p "$VIDEOS_DIR"

# Instagram now blocks anonymous downloads ("empty media response"). If a
# cookies.txt exists in reel-engine, pass it to yt-dlp so authenticated
# downloads work. Netscape-format cookie file; exported from a logged-in
# browser session. Absent file => yt-dlp runs without auth (may fail).
COOKIES_FILE="${HOME}/reel-engine/cookies.txt"
COOKIE_ARGS=()
if [ -f "$COOKIES_FILE" ]; then
    COOKIE_ARGS=(--cookies "$COOKIES_FILE")
fi

echo "Downloading reel..."
# One yt-dlp call returns id, uploader, uploader_id, and description (the caption).
# Separating fields with NUL bytes would be cleaner, but --print emits lines.
# We tolerate captions with embedded newlines by joining everything after line 3.
META=$(yt-dlp --no-playlist "${COOKIE_ARGS[@]}" --print "%(id)s"$'\n'"%(uploader)s"$'\n'"%(uploader_id)s"$'\n'"%(description)s" "$URL" 2>/dev/null || true)
REEL_ID=$(printf '%s' "$META" | sed -n '1p')
UPLOADER=$(printf '%s' "$META" | sed -n '2p')
UPLOADER_ID=$(printf '%s' "$META" | sed -n '3p')
# Everything from line 4 onward is the caption. May span multiple lines.
CAPTION=$(printf '%s' "$META" | tail -n +4)

# Sanitize REEL_ID — defense in depth. Instagram shortcodes are alphanumeric +
# _ - but we don't trust the extractor. Whitelist + length cap.
REEL_ID=$(printf '%s' "$REEL_ID" | tr -cd '[:alnum:]_-' | cut -c1-32)
if [ -z "$REEL_ID" ]; then
    echo "Error: could not fetch a valid reel ID. The reel may be private, deleted, rate-limited, or the URL may be malformed." >&2
    exit 1
fi

# Instagram often returns an empty uploader (display name) anonymously; yt-dlp
# renders missing fields as "NA". Fall back to the @handle before "unknown".
if [ -z "$UPLOADER" ] || [ "$UPLOADER" = "NA" ]; then
    UPLOADER="$UPLOADER_ID"
fi
if [ -z "$UPLOADER" ] || [ "$UPLOADER" = "NA" ]; then
    UPLOADER="unknown"
fi

# Refuse to re-process a reel that already has canonical outputs, either in the
# chosen output dir or in the legacy dir. The ReelID is known BEFORE downloading,
# so this early exit saves the download AND the whisper run that the late
# canonical-name check below could only catch afterwards.
for dir in "$VIDEOS_DIR" "$LEGACY_DIR"; do
    existing=$(ls "$dir"/*"(${REEL_ID}).mp4" 2>/dev/null | head -1 || true)
    if [ -n "$existing" ]; then
        echo "Error: this reel was already processed:" >&2
        echo "  $existing" >&2
        echo "Run /reel-decode on it, or delete the existing files to re-download." >&2
        exit 1
    fi
done

RAW_PATH="$VIDEOS_DIR/${REEL_ID}.mp4"

# Refuse to clobber an existing download
if [ -e "$RAW_PATH" ]; then
    echo "Error: $RAW_PATH already exists." >&2
    echo "Remove it first if you want to re-process this reel:" >&2
    echo "  rm \"$RAW_PATH\"" >&2
    exit 1
fi

# Prefer H.264/AAC so the file opens in Premiere Pro and other editors
# (Instagram often serves VP9, which Premiere can't decode). -S sorts formats
# to favor h264 video + aac audio when available.
yt-dlp --no-playlist "${COOKIE_ARGS[@]}" -S "vcodec:h264,acodec:aac" -o "$RAW_PATH" "$URL"

if [ ! -f "$RAW_PATH" ]; then
    echo "Error: download completed but file not found at $RAW_PATH" >&2
    exit 1
fi

# Fallback: if Instagram only offered VP9/AV1, re-encode to H.264 so editors
# (Premiere Pro, etc.) can open the file.
VCODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$RAW_PATH" || true)
if [ "$VCODEC" != "h264" ]; then
    echo "Downloaded codec is '$VCODEC' — re-encoding to H.264 for editor compatibility..."
    TMP_H264="${RAW_PATH%.mp4}.h264tmp.mp4"
    # -y and -loglevel are global options; placed after the output file ffmpeg
    # treats them as trailing options and ignores them.
    ffmpeg -y -loglevel error -i "$RAW_PATH" -c:v libx264 -preset fast -crf 18 -pix_fmt yuv420p \
        -c:a aac -b:a 192k -movflags +faststart "$TMP_H264"
    mv -f "$TMP_H264" "$RAW_PATH"
fi

echo "Transcribing (this may take a minute; first run downloads ~150MB model)..."
# No --language flag: Whisper auto-detects and prints "Detected language: X".
# Forcing English on a Portuguese reel produces silent garbage that poisons
# /reel-decode and /reel-adapt downstream.
whisper "$RAW_PATH" --model base --output_format srt --output_dir "$VIDEOS_DIR"
SRT_PATH="$VIDEOS_DIR/${REEL_ID}.srt"

if [ ! -f "$SRT_PATH" ]; then
    echo "Error: transcription failed — no SRT at $SRT_PATH" >&2
    exit 1
fi

# Get first non-empty caption line from SRT. Whitelist alphanumerics, space,
# underscore, dash — prevents filename injection (unicode slashes, newlines,
# path traversal). Cap length for filename safety.
FIRST_LINE=$(grep -v "^[0-9]*$" "$SRT_PATH" \
    | grep -v "^[0-9].*-->" \
    | grep -v "^$" \
    | head -1 \
    | tr -cd '[:alnum:][:space:]_-' \
    | tr -s '[:space:]' ' ' \
    | cut -c1-50 \
    | sed 's/^ *//;s/ *$//')
if [ -z "$FIRST_LINE" ]; then
    FIRST_LINE="untitled"
fi

# Same sanitization + length cap for uploader
CLEAN_UPLOADER=$(printf '%s' "$UPLOADER" \
    | tr -cd '[:alnum:][:space:]_-' \
    | tr -s '[:space:]' ' ' \
    | cut -c1-50 \
    | sed 's/^ *//;s/ *$//')
if [ -z "$CLEAN_UPLOADER" ]; then
    CLEAN_UPLOADER="unknown"
fi

FINAL_NAME="${CLEAN_UPLOADER} - ${FIRST_LINE} (${REEL_ID})"
FINAL_MP4="$VIDEOS_DIR/${FINAL_NAME}.mp4"
FINAL_SRT="$VIDEOS_DIR/${FINAL_NAME}.srt"

# Refuse to clobber final names either (defense in depth; the early ReelID
# check above should normally catch this before any download happens)
if [ -e "$FINAL_MP4" ] || [ -e "$FINAL_SRT" ]; then
    echo "Error: a file with the canonical name already exists:" >&2
    echo "  $FINAL_MP4" >&2
    echo "Remove the existing .mp4 and .srt if you want to re-process this reel:" >&2
    echo "  rm \"$FINAL_MP4\" \"$FINAL_SRT\"" >&2
    # The raw mp4/srt we just produced are duplicates of already-processed
    # content; remove them so they don't pile up as orphans.
    rm -f "$RAW_PATH" "$SRT_PATH"
    echo "(cleaned up the duplicate download)" >&2
    exit 1
fi

# Use -n as a second defense against TOCTOU race between -e check and mv
mv -n "$RAW_PATH" "$FINAL_MP4"
mv -n "$SRT_PATH" "$FINAL_SRT"

# --- Text-overlay detection ---
#
# Many viral reels have no speech — they use on-screen text and background
# music. Whisper transcribes the music into garbage ("[Music]", hallucinated
# phrases, or a few scattered words), which poisons /reel-decode and /reel-adapt
# if we treat it as a real spoken script. The real content in those reels
# lives in the caption (post description).
#
# Heuristic: count real words in the SRT. If fewer than 15 real words survive
# after stripping music/applause tags, treat it as text-overlay. 15 is a soft
# threshold — tuned so a 5-second greeting still counts as spoken but a
# 30-second music-only reel with one alert word gets caught.
# KEEP IN SYNC: the reel-decode skill (skills/reel-decode/SKILL.md) runs the
# same 15-word fallback inline when no meta.json exists (Mode B uploads).
#
# PY picker: python3 on most systems, python on Windows Git Bash.
# On Windows the bare `python3`/`python` names often resolve to the broken
# Microsoft Store App-execution-alias stub (in WindowsApps) which errors with
# "Python was not found". Probe each candidate by actually running it, and
# include the known real install path as a fallback.
PY=""
for cand in python3 python \
    "/c/Users/${USERNAME:-$USER}/AppData/Local/Programs/Python/Python313/python.exe" \
    "/c/Users/${USERNAME:-$USER}/AppData/Local/Programs/Python/Python312/python.exe"; do
    if command -v "$cand" &>/dev/null && "$cand" --version &>/dev/null; then
        PY="$cand"
        break
    fi
done
if [ -z "$PY" ]; then
    echo "Error: no working Python interpreter found." >&2
    exit 1
fi

CONTENT_MODE=$("$PY" - "$FINAL_SRT" <<'PYEOF'
import re, sys, pathlib
srt = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
# Strip SRT index lines, timestamp lines, blank lines.
# What remains is the spoken text.
text_lines = []
for line in srt.splitlines():
    if not line.strip():
        continue
    if re.match(r"^\d+$", line.strip()):
        continue
    if "-->" in line:
        continue
    text_lines.append(line)
text = " ".join(text_lines)
# Strip common non-speech markers Whisper emits for music/applause/noise.
text = re.sub(r"[\[\(][^\]\)]*[\]\)]", " ", text)
words = re.findall(r"[A-Za-z\u00C0-\u024F]+", text)
# Print the verdict on one line so bash can capture it.
print("text_overlay" if len(words) < 15 else "spoken")
PYEOF
)

META_PATH="$VIDEOS_DIR/${FINAL_NAME}.meta.json"

# Write a small companion JSON next to the mp4/srt. /reel-decode and /reel-adapt
# read this to decide whether to treat the reel as spoken or text-overlay.
# Using python for JSON because we already rely on it above, and it handles
# caption escaping for us (newlines, quotes, unicode).
"$PY" - "$META_PATH" "$REEL_ID" "$CONTENT_MODE" "$CAPTION" <<'PYEOF'
import json, sys
out_path, reel_id, content_mode, caption = sys.argv[1:5]
data = {
    "reel_id": reel_id,
    "content_mode": content_mode,  # "spoken" or "text_overlay"
    "caption": caption or "",
}
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PYEOF

echo ""
echo "Done."
echo "Video: $FINAL_MP4"
echo "SRT:   $FINAL_SRT"
echo "Meta:  $META_PATH"
echo "Mode:  $CONTENT_MODE"
if [ "$CONTENT_MODE" = "text_overlay" ]; then
    echo ""
    echo "Note: this looks like a text-overlay reel (little or no speech)."
    echo "The caption will be used as the source content instead of the transcript."
fi
