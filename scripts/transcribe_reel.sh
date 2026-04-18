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

# Validate URL — only Instagram, only https. Prevents SSRF and accidental misuse.
if [[ ! "$URL" =~ ^https://(www\.)?instagram\.com/ ]]; then
    echo "Error: URL must start with https://instagram.com/ or https://www.instagram.com/" >&2
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

# Verify required dependencies are installed
missing=()
for cmd in yt-dlp whisper ffmpeg; do
    if ! command -v "$cmd" &>/dev/null; then
        missing+=("$cmd")
    fi
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo "Error: missing required tools: ${missing[*]}" >&2
    echo "Install them and try again. See README.md for platform-specific commands." >&2
    exit 1
fi

mkdir -p "$VIDEOS_DIR"

echo "Downloading reel..."
# --no-playlist prevents accidental bulk downloads if URL resolves to a profile
REEL_ID=$(yt-dlp --no-playlist --print id "$URL" 2>/dev/null | tail -1 || true)
UPLOADER=$(yt-dlp --no-playlist --print uploader "$URL" 2>/dev/null | tail -1 || true)

if [ -z "$REEL_ID" ]; then
    echo "Error: could not fetch reel ID. The reel may be private, deleted, or the URL may be malformed." >&2
    exit 1
fi
if [ -z "$UPLOADER" ]; then
    UPLOADER="unknown"
fi

RAW_PATH="$VIDEOS_DIR/${REEL_ID}.mp4"
yt-dlp --no-playlist -o "$RAW_PATH" "$URL"

if [ ! -f "$RAW_PATH" ]; then
    echo "Error: download completed but file not found at $RAW_PATH" >&2
    exit 1
fi

echo "Transcribing (this may take a minute)..."
# Pin to 'base' model — ~150MB, good speed/quality tradeoff. First run downloads it.
whisper "$RAW_PATH" --language en --model base --output_format srt --output_dir "$VIDEOS_DIR"
SRT_PATH="$VIDEOS_DIR/${REEL_ID}.srt"

if [ ! -f "$SRT_PATH" ]; then
    echo "Error: transcription failed — no SRT at $SRT_PATH" >&2
    exit 1
fi

# Get first non-empty line from SRT as title.
# Keep only alphanumerics, space, underscore, dash — prevents filename injection
# via malicious captions (unicode slashes, newlines, path traversal, etc.).
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

# Same sanitization for the uploader name
CLEAN_UPLOADER=$(echo "$UPLOADER" \
    | tr -cd '[:alnum:][:space:]_-' \
    | tr -s '[:space:]' ' ' \
    | sed 's/^ *//;s/ *$//')
if [ -z "$CLEAN_UPLOADER" ]; then
    CLEAN_UPLOADER="unknown"
fi

FINAL_NAME="${CLEAN_UPLOADER} - ${FIRST_LINE} (${REEL_ID})"
FINAL_MP4="$VIDEOS_DIR/${FINAL_NAME}.mp4"
FINAL_SRT="$VIDEOS_DIR/${FINAL_NAME}.srt"

mv "$RAW_PATH" "$FINAL_MP4"
mv "$SRT_PATH" "$FINAL_SRT"

echo ""
echo "Done."
echo "Video: $FINAL_MP4"
echo "SRT:   $FINAL_SRT"
