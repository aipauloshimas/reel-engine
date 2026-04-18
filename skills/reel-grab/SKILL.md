---
name: reel-grab
description: Downloads or receives an Instagram reel and prepares it for analysis. Transcribes audio to SRT and extracts frames at 1fps. Use whenever the user provides an Instagram URL or uploads a video file and wants to start the reel analysis pipeline. Always runs before /reel-decode.
---

# /reel-grab — The Downloader

You prepare a reel for analysis. Your job: get the video, transcription, and frames into the right place so `/reel-decode` can do its work.

## Canonical paths and naming

Everything lives under `~/reel-engine/Reels/Videos/`. The pipeline script produces files named:

```
{AuthorName} - {Title} (ReelID).mp4
{AuthorName} - {Title} (ReelID).srt
```

Where `Title` is the first spoken line of the transcription, truncated to 50 chars and sanitized for safe filenames. `AuthorName` can contain spaces.

Call the portion before `.mp4` the **BaseName** — you will reuse it for the frames folder and every downstream file.

- `AuthorName` = everything before the last ` - ` in BaseName (strips off the title + ReelID)
- `AuthorSlug` = `AuthorName` with spaces replaced by underscores (used for folder names because some tools dislike spaces)
- `FramesDir` = `~/reel-engine/Reels/Videos/frames_{AuthorSlug}/`

Keep this mapping consistent — `/reel-decode` and `/reel-adapt` both rely on it.

## Two modes

### Mode A — URL provided

Run the pipeline script. It validates the URL, downloads, transcribes with Whisper (model `base`), and renames.

```bash
bash ~/reel-engine/scripts/transcribe_reel.sh "<URL>"
```

The script will fail fast with a human-readable message if:
- The URL is not an `https://instagram.com/` URL
- `yt-dlp`, `whisper`, or `ffmpeg` is missing
- The reel is private/deleted/rate-limited (no reel ID returned)

If it fails, read the error and tell the user what to do. Don't retry blindly.

### Mode B — Video file already exists (upload or local file)

Ask the user for the video file path if not clear from context. Then:

```bash
whisper "<video_path>" --language en --model base --output_format srt --output_dir ~/reel-engine/Reels/Videos/
```

Rename the resulting `.srt` so its basename matches the video's basename exactly.

## Frame extraction (both modes)

After you have `BaseName.mp4` in place, extract frames at 1fps. Derive the paths **from the actual file you just produced** — do not use placeholder strings.

```bash
VIDEOS_DIR=~/reel-engine/Reels/Videos
# Pick the most recent .mp4 — avoids placeholder substitution errors
VIDEO_PATH=$(ls -t "$VIDEOS_DIR"/*.mp4 2>/dev/null | head -1)
BASE_NAME="$(basename "$VIDEO_PATH" .mp4)"
AUTHOR_NAME="${BASE_NAME%% - *}"                 # everything before the first " - "
AUTHOR_SLUG="${AUTHOR_NAME// /_}"                # spaces → underscores
FRAMES_DIR="$VIDEOS_DIR/frames_${AUTHOR_SLUG}"

mkdir -p "$FRAMES_DIR"
ffmpeg -i "$VIDEO_PATH" -vf fps=1 "$FRAMES_DIR/frame_%03d.jpg" -y
```

If the user has multiple `.mp4` files in Videos/ and you want a specific one, substitute `VIDEO_PATH` with the actual full path — never leave a literal placeholder in the executed command.

## Confirm and hand off

When done, tell the user:
- The `BaseName` (so they can reference it)
- Frame count (count files in `FRAMES_DIR`)
- Next step: run `/reel-decode`

## If something goes wrong

- **"could not fetch reel ID"** → the reel is private, deleted, or Instagram is rate-limiting. Wait a few minutes or try a different reel.
- **"missing required tools"** → stop and point the user to the README's Install section.
- **Whisper downloading ~150MB on first run** → this is normal. Tell the user once so they don't think it's stuck.
