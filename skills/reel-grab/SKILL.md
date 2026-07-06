---
name: reel-grab
description: Use when the user provides an Instagram reel URL, or uploads/points at a local video file, and wants to start the reel analysis pipeline. Always runs before /reel-decode. Triggers on /reel-grab, an instagram.com/reel link, or "baixa esse reel".
---

# /reel-grab: The Downloader

You prepare a reel for analysis. Your job: get the video, transcription, and frames into the right place so `/reel-decode` can do its work.

## Where outputs go: the session folder

All pipeline outputs (mp4, srt, meta.json, frames, and later the storyboard and adapted script) are saved in the **session folder**: the current working directory of this conversation (e.g. `C:\Users\paulo\AI\Paulo\v68`). Call it `SessionDir`.

- If the user names a different destination, use that as SessionDir.
- If the session is running somewhere generic (the home directory, a temp folder), ask where to save, suggesting `~/reel-engine/Reels/Videos/` (the legacy default where older reels live).

Tooling stays global: the pipeline script, `VOICE.md`, and `cookies.txt` live in `~/reel-engine/`.

## Canonical naming

The pipeline script produces files named:

```
{AuthorName} - {Title} (ReelID).mp4
{AuthorName} - {Title} (ReelID).srt
```

Where `Title` is the first spoken line of the transcription, truncated to 50 chars and sanitized for safe filenames. `AuthorName` can contain spaces.

Call the portion before `.mp4` the **BaseName**. You will reuse it for the frames folder and every downstream file.

- `AuthorName` = everything before the **first** ` - ` in BaseName (the Title itself may contain ` - `, so never split on the last one)
- `ReelID` = the content of the final `(...)` in BaseName
- `AuthorSlug` = `AuthorName` with spaces replaced by underscores (folder names, some tools dislike spaces)
- `FramesDir` = `{SessionDir}/frames_{AuthorSlug}_{ReelID}/`

The ReelID in FramesDir is not optional. Two reels by the same author must never share a frames folder; when they do, their frames mix and `/reel-decode` silently analyzes a blend of two different videos.

Keep this mapping consistent: `/reel-decode` and `/reel-adapt` both rely on it.

## Two modes

### Mode A: URL provided

Run the pipeline script, passing SessionDir as the output directory:

```bash
bash ~/reel-engine/scripts/transcribe_reel.sh "<URL>" "<SessionDir>"
```

The script validates the URL, refuses to re-download an already-processed reel, downloads, transcribes with Whisper (language auto-detected, model `base`), renames, and writes the meta.json sidecar. Watch for the `Detected language:` line Whisper prints and relay it to the user; a wrong detection is the earliest warning of a garbage transcript.

The script fails fast with a human-readable message if:
- The URL is not an `https://instagram.com/` URL
- `yt-dlp`, `whisper`, or `ffmpeg` is missing (run `/reel-doctor` to fix)
- The reel is private/deleted/rate-limited, or the Instagram cookies are stale (no reel ID returned)
- The reel was already processed (the error prints where the existing file is)

If it fails, read the error and tell the user what to do. Don't retry blindly.

### Mode B: video file already exists (upload or local file)

Ask the user for the video file path if not clear from context. **Copy** the file into SessionDir (copy, not move: the user's original stays where they put it), renamed to the canonical `{Author} - {Title} (ID).mp4` form so downstream parsing works. If you don't know a real Author/ID, use a unique timestamp-based ID so a second upload never collides:

```bash
LOCAL_ID="local$(date +%y%m%d%H%M%S)"
VIDEO_PATH="<SessionDir>/user_upload - myclip (${LOCAL_ID}).mp4"
cp "<source_path>" "$VIDEO_PATH"

# Run Whisper on it. Do NOT force --language: Whisper auto-detects, and forcing
# English on a Portuguese reel produces silent garbage. Default model is `base`;
# substitute small|medium|large if the user asks for higher accuracy over speed.
whisper "$VIDEO_PATH" --model base --output_format srt --output_dir "<SessionDir>"
```

Whisper writes the `.srt` using the video's basename, so the SRT matches automatically. Report the `Detected language:` line to the user.

Remember `VIDEO_PATH` and pass it directly to the frame-extraction step below. Do **not** re-derive it via `ls -t`, which silently picks the wrong file when the folder has other reels.

## Frame extraction (both modes)

After you have the final `.mp4` in place, extract frames at 1fps. **Use the exact `VIDEO_PATH` you just worked with** (Mode A: the `Video:` path printed by the script; Mode B: the path you used with Whisper).

```bash
VIDEO_PATH="<the exact .mp4 path you just produced>"   # pass this in explicitly
BASE_NAME="$(basename "$VIDEO_PATH" .mp4)"
AUTHOR_NAME="${BASE_NAME%% - *}"                       # everything before the FIRST " - "
AUTHOR_SLUG="${AUTHOR_NAME// /_}"                      # spaces to underscores
REEL_ID="${BASE_NAME##*(}"                             # content of the final (...)
REEL_ID="${REEL_ID%)}"
FRAMES_DIR="$(dirname "$VIDEO_PATH")/frames_${AUTHOR_SLUG}_${REEL_ID}"

mkdir -p "$FRAMES_DIR"
rm -f "$FRAMES_DIR"/frame_*.jpg   # clear leftovers from any earlier run; stale high-numbered frames poison /reel-decode
ffmpeg -y -i "$VIDEO_PATH" -vf fps=1 "$FRAMES_DIR/frame_%03d.jpg"
```

If `BASE_NAME` has no `(...)` suffix, `REEL_ID` ends up as the whole filename and the folder name gets ugly. Prefer renaming to canonical form before this step so that never happens.

## Content mode detection (Mode A only: automatic)

Mode A's script writes a sidecar file next to the video:

```
{BaseName}.meta.json
```

It contains `reel_id`, `caption` (the post description from Instagram), and `content_mode`:

- `"spoken"`: normal reel with speech, transcript is the primary content
- `"text_overlay"`: little or no real speech, caption is the primary content

`/reel-decode` and `/reel-adapt` read this file to decide how to treat the reel. You don't need to do anything with it in `/reel-grab`. Just let the user know which mode was detected; the script prints `Mode: spoken|text_overlay` at the end.

**Mode B doesn't write meta.json automatically.** That's fine: `/reel-decode` runs the same detection inline on the SRT when no meta.json is present. Captions won't be available for Mode B uploads, so text-overlay handling falls back to analyzing the frames + on-screen text only.

## Confirm and hand off

When done, tell the user:
- The `BaseName` and the folder it was saved in (SessionDir)
- Frame count (count files in `FRAMES_DIR`)
- The language Whisper detected
- The detected content mode (only Mode A; say nothing if Mode B)
- Next step: run `/reel-decode`

## If something goes wrong

- **Download fails, "empty media response", or login-required errors** = the Instagram cookies are stale. Re-export `cookies.txt` from a logged-in browser (extension "Get cookies.txt LOCALLY") to `~/reel-engine/cookies.txt` and retry.
- **"could not fetch reel ID"** (with fresh cookies) = the reel is private, deleted, or Instagram is rate-limiting. Wait a few minutes or try a different reel.
- **"already processed"** = the reel exists; the error prints where. Run `/reel-decode` on the existing files, or delete them first to re-download.
- **"missing required tools"** = run `/reel-doctor`; it checks and repairs every dependency.
- **Whisper downloading ~150MB on first run** = normal. Tell the user once so they don't think it's stuck.
- **Wrong `Detected language`** = re-run Whisper for that reel only with an explicit `--language <code>`.
