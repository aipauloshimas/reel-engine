---
name: reel-doctor
description: Use when any reel-engine skill fails with a missing tool, a download or transcription error, or on first-time setup of the pipeline. Triggers on /reel-doctor or errors mentioning yt-dlp, whisper, ffmpeg, or stale Instagram cookies.
---

# /reel-doctor: System Check and Repair

You check every dependency the reel pipeline needs, report the results in one table, and fix what's broken. Never install anything without telling the user what you're about to run.

## Checks (run all, then report all at once)

```bash
# A real Python interpreter (the Microsoft Store alias stub fails --version)
python --version 2>/dev/null || python3 --version 2>/dev/null

ffmpeg -version 2>/dev/null | head -1
yt-dlp --version 2>/dev/null
whisper --help >/dev/null 2>&1 && echo "whisper OK"
```

Also check:

- **`~/reel-engine/cookies.txt`**: exists? Modified in the last ~30 days? Stale or missing cookies are the top cause of failed downloads ("empty media response", login-required errors). Check with `ls -la ~/reel-engine/cookies.txt`.
- **`~/reel-engine/VOICE.md`**: any of the first 3 lines contains `STATUS: configured`? If not, `/reel-adapt` will refuse to write scripts.
- **`~/reel-engine/scripts/transcribe_reel.sh`**: exists and is readable.

## Report format

One compact table, every row filled:

| Component | Status | Fix |
|---|---|---|
| python | OK 3.13.2 / MISSING | ... |
| ffmpeg | OK / MISSING | ... |
| yt-dlp | OK 2026.x / MISSING | ... |
| whisper | OK / MISSING | ... |
| cookies.txt | OK (5 days old) / STALE (40 days) / MISSING | ... |
| VOICE.md | configured / template / missing | ... |
| pipeline script | OK / MISSING | ... |

Then apply the fixes the user approves, one at a time, and re-run the failed probe after each to confirm.

## Fixes

- **python missing or stub**: `winget install Python.Python.3.13`, then restart the terminal. The Microsoft Store alias in WindowsApps is not a real interpreter; the pipeline script already probes past it, but pip installs need the real one.
- **ffmpeg missing (Windows)**: `winget install Gyan.FFmpeg`, then restart the terminal so PATH refreshes. The pipeline script also auto-discovers the WinGet install location, so Mode A may work even before the restart.
- **yt-dlp or whisper missing**: `pip install -U yt-dlp openai-whisper` (with the working Python found above). On first transcription Whisper downloads a ~150MB model; that's normal.
- **cookies.txt missing or stale**: log into Instagram in the browser, export with the "Get cookies.txt LOCALLY" extension, save to `~/reel-engine/cookies.txt`. Without it, Instagram blocks anonymous downloads.
- **VOICE.md not configured**: run `/voice-setup` (5-minute interview).
- **pipeline script missing**: the reel-engine install is broken or moved; re-clone or restore `~/reel-engine/` per the README's Install section.

## Closing

End by telling the user which command to retry (usually the `/reel-grab` that failed). If everything was already OK, say so and point to `/reel-start` for the menu.
