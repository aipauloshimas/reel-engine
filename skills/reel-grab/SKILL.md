---
name: reel-grab
description: Downloads or receives an Instagram reel and prepares it for analysis. Transcribes audio to SRT and extracts frames at 1fps. Use whenever the user provides an Instagram URL or uploads a video file and wants to start the reel analysis pipeline. Always runs before /reel-decode.
---

# /reel-grab — The Downloader

You prepare a reel for analysis. Your job: get the video, transcription, and frames into the right place so `/reel-decode` can do its work.

## Canonical paths and naming

Everything lives under `~/reel-engine/Reels/Videos/`. The pipeline script produces files named:

```
{AuthorName} - {FirstSrtLine} (ReelID).mp4
{AuthorName} - {FirstSrtLine} (ReelID).srt
```

Call the portion before `.mp4` the **BaseName** — you will reuse it for the frames folder and every downstream file.

- `AuthorName` = the part of BaseName before the first ` - `
- `AuthorSlug` = `AuthorName` with spaces replaced by underscores (used for folder names because some tools dislike spaces)
- `FramesDir` = `~/reel-engine/Reels/Videos/frames_{AuthorSlug}/`

Keep this mapping consistent — `/reel-decode` relies on it.

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
VIDEO_PATH="$VIDEOS_DIR/<BaseName>.mp4"          # fill in BaseName from the actual file
BASE_NAME="$(basename "$VIDEO_PATH" .mp4)"
AUTHOR_NAME="${BASE_NAME% - *}"                  # everything before the first " - "
AUTHOR_NAME="${AUTHOR_NAME%% - *}"               # collapse if multiple separators
AUTHOR_SLUG="${AUTHOR_NAME// /_}"                # spaces → underscores
FRAMES_DIR="$VIDEOS_DIR/frames_${AUTHOR_SLUG}"

mkdir -p "$FRAMES_DIR"
ffmpeg -i "$VIDEO_PATH" -vf fps=1 "$FRAMES_DIR/frame_%03d.jpg" -y
```

Run the commands above with real values substituted — never leave `<BaseName>` literal.

## Confirm and hand off

When done, tell the user:
- The `BaseName` (so they can reference it)
- Frame count (count files in `FRAMES_DIR`)
- Next step: run `/reel-decode`

## If something goes wrong

- **"could not fetch reel ID"** → the reel is private, deleted, or Instagram is rate-limiting. Wait a few minutes or try a different reel.
- **"missing required tools"** → stop and point the user to the README's Install section.
- **Whisper downloading ~150MB on first run** → this is normal. Tell the user once so they don't think it's stuck.
