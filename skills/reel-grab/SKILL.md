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

Ask the user for the video file path if not clear from context. Copy or move the file into `~/reel-engine/Reels/Videos/` first — ideally renamed to the canonical `{Author} - {Title} (ID).mp4` form so downstream parsing works. If you don't know a real Author/ID, use any unique name with at least one ` - ` separator. Example (substitute the real source path):

```bash
mv "<source_path>" ~/reel-engine/Reels/Videos/"user_upload - myclip (local001).mp4"
VIDEO_PATH=~/reel-engine/Reels/Videos/"user_upload - myclip (local001).mp4"

# Run Whisper on it. Default model is `base`; substitute small|medium|large if the user
# explicitly asks for higher accuracy at the cost of speed.
whisper "$VIDEO_PATH" --language en --model base --output_format srt --output_dir ~/reel-engine/Reels/Videos/
```

Whisper writes the `.srt` using the video's basename, so if the video is named correctly the SRT matches automatically. If you had to rename, rename the SRT to match too.

Remember `VIDEO_PATH` — pass it directly to the frame-extraction step below. Do **not** re-derive it via `ls -t`.

## Frame extraction (both modes)

After you have the final `.mp4` in place, extract frames at 1fps. **Use the exact `VIDEO_PATH` you just worked with** — for Mode A that's the `FINAL_MP4` printed by the script; for Mode B that's the path you used with Whisper. Never recover it via `ls -t`, which silently picks the wrong file when Videos/ has other reels.

```bash
VIDEO_PATH="<the exact .mp4 path you just produced>"   # pass this in explicitly
BASE_NAME="$(basename "$VIDEO_PATH" .mp4)"
AUTHOR_NAME="${BASE_NAME%% - *}"                       # everything before the first " - "
AUTHOR_SLUG="${AUTHOR_NAME// /_}"                      # spaces → underscores
FRAMES_DIR="$(dirname "$VIDEO_PATH")/frames_${AUTHOR_SLUG}"

mkdir -p "$FRAMES_DIR"
ffmpeg -i "$VIDEO_PATH" -vf fps=1 "$FRAMES_DIR/frame_%03d.jpg" -y
```

If `BASE_NAME` contains no ` - ` separator, `AUTHOR_NAME` ends up equal to the whole filename — that's fine for Mode B uploads, it just produces a slightly ugly folder name. Prefer renaming the upload to canonical form before you run this.

## Confirm and hand off

When done, tell the user:
- The `BaseName` (so they can reference it)
- Frame count (count files in `FRAMES_DIR`)
- Next step: run `/reel-decode`

## If something goes wrong

- **"could not fetch reel ID"** → the reel is private, deleted, or Instagram is rate-limiting. Wait a few minutes or try a different reel.
- **"missing required tools"** → stop and point the user to the README's Install section.
- **Whisper downloading ~150MB on first run** → this is normal. Tell the user once so they don't think it's stuck.
