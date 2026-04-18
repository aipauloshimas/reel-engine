#!/bin/bash
# transcribe_reel.sh — download, transcribe, and rename an Instagram reel
# Usage: bash transcribe_reel.sh "<URL>"

set -euo pipefail

URL="${1:-}"
VIDEOS_DIR="${HOME}/reel-engine/Reels/Videos"

if [ -z "$URL" ]; then
    echo "Usage: bash transcribe_reel.sh <instagram_url>" >&2
    exit 1
fi

# Validate URL — only Instagram host, only https. Anchored path prevents
# hosts like instagram.com.evil.com. Prevents SSRF and accidental misuse.
if [[ ! "$URL" =~ ^https://(www\.)?instagram\.com(/|$) ]]; then
    echo "Error: URL must be https://instagram.com/... or https://www.instagram.com/..." >&2
    echo "Got: $URL" >&2
    exit 1
fi

# On Windows (Git Bash / MSYS), try to find ffmpeg from WinGet if not in PATH
if [[ "${OSTYPE:-}" == "msys" || "${OSTYPE:-}" == "cygwin" ]]; then
    if ! command -v ffmpeg &>/dev/null; then
        WINGET_FFMPEG=$(find "/c/Users/${USERNAME:-$USER}/AppData/Local/Microsoft/WinGet/Packages" -name "ffmpeg.exe" 2>/dev/null | head -1 || true)
        if [ -n "$WINGET_FFMPEG" ]; then
            export PATH="$(dirname "$WINGET_FFMPEG"):$PATH"
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

echo "Downloading reel..."
REEL_ID=$(yt-dlp --no-playlist --print id "$URL" 2>/dev/null | tail -1 || true)
UPLOADER=$(yt-dlp --no-playlist --print uploader "$URL" 2>/dev/null | tail -1 || true)

# Sanitize REEL_ID — defense in depth. Instagram shortcodes are alphanumeric +
# _ - but we don't trust the extractor. Whitelist + length cap.
REEL_ID=$(printf '%s' "$REEL_ID" | tr -cd '[:alnum:]_-' | cut -c1-32)
if [ -z "$REEL_ID" ]; then
    echo "Error: could not fetch a valid reel ID. The reel may be private, deleted, rate-limited, or the URL may be malformed." >&2
    exit 1
fi

if [ -z "$UPLOADER" ]; then
    UPLOADER="unknown"
fi

RAW_PATH="$VIDEOS_DIR/${REEL_ID}.mp4"

# Refuse to clobber an existing download
if [ -e "$RAW_PATH" ]; then
    echo "Error: $RAW_PATH already exists. Delete it or use a different reel." >&2
    exit 1
fi

yt-dlp --no-playlist -o "$RAW_PATH" "$URL"

if [ ! -f "$RAW_PATH" ]; then
    echo "Error: download completed but file not found at $RAW_PATH" >&2
    exit 1
fi

echo "Transcribing (this may take a minute; first run downloads ~150MB model)..."
whisper "$RAW_PATH" --language en --model base --output_format srt --output_dir "$VIDEOS_DIR"
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

# Refuse to clobber final names either
if [ -e "$FINAL_MP4" ] || [ -e "$FINAL_SRT" ]; then
    echo "Error: a file with the canonical name already exists:" >&2
    echo "  $FINAL_MP4" >&2
    echo "Delete it first if you want to re-process this reel." >&2
    # leave the raw files intact so user can inspect
    exit 1
fi

mv "$RAW_PATH" "$FINAL_MP4"
mv "$SRT_PATH" "$FINAL_SRT"

echo ""
echo "Done."
echo "Video: $FINAL_MP4"
echo "SRT:   $FINAL_SRT"
