# reel-engine

Analyze any Instagram reel frame-by-frame, extract exactly why it works, and adapt it for your product — with a spoken script, shot-by-shot breakdown, and full production storyboard.

Built by [shimas](https://github.com/aipauloshimas).

---

## What it does

Five Claude Code skills that work together:

| Skill | What it does |
|---|---|
| `/reel-start` | Orientation menu. Run this if you're unsure where to begin. |
| `/voice-setup` | 5-minute interview to discover your on-camera voice. Run once. |
| `/reel-grab` | Downloads a reel from a URL (or transcribes one you upload). Extracts frames at 1fps. |
| `/reel-decode` | Analyzes every frame. Produces a storyboard + persuasion breakdown + 3 targeted questions. |
| `/reel-adapt` | Takes your answers and writes an adapted script, shot-by-shot breakdown, and full production storyboard. |

---

## Requirements

Only one: [Claude Code](https://claude.ai/code) with your Anthropic API key configured.

The install below handles everything else — Git, Python, ffmpeg, Whisper, yt-dlp, and copying the skills — and only installs what you're actually missing.

---

## Install

Open Claude Code in any folder and paste this message exactly:

````
Install reel-engine from https://github.com/aipauloshimas/reel-engine.

Detect my OS first (macOS / Linux / Windows) and use the right package manager
(brew / apt-or-dnf-or-pacman / winget). For every dependency below: check if
it's already installed with a version command. Only install what's missing.
Stop and tell me if any step fails — don't try clever workarounds.

1. Safety check — if ~/reel-engine/ already exists, stop and ask me before
   doing anything else. Never overwrite.

2. Git — run `git --version`. If missing, install:
     - macOS:   brew install git          (install Homebrew first if missing)
     - Linux:   use the distro's package manager
     - Windows: winget install --id Git.Git -e

3. Python 3.8+ — run `python --version` then `python3 --version`. Need one
   that reports 3.8 or higher. If neither works:
     - macOS:   brew install python
     - Linux:   distro package manager (python3 + python3-pip)
     - Windows: winget install --id Python.Python.3.12 -e
   After install, verify pip works: `pip --version` (or `pip3 --version`).

4. ffmpeg — run `ffmpeg -version`. If missing:
     - macOS:   brew install ffmpeg
     - Linux:   distro package manager
     - Windows: winget install --id Gyan.FFmpeg -e
   On Windows, open a fresh shell after install so PATH refreshes.

5. Clone the repo to ~/reel-engine/ (use HTTPS, not SSH).

6. Install the Python deps:
     pip install -r ~/reel-engine/requirements.txt
   This installs openai-whisper and yt-dlp. Whisper pulls in ~150MB of model
   data on first transcription — that's normal, warn me when it happens, not
   now.

7. Copy every folder inside ~/reel-engine/skills/ into ~/.claude/skills/
   (on Windows: %USERPROFILE%\.claude\skills\). Create the target directory
   if it doesn't exist. Don't overwrite unrelated skill folders already there.

8. Verify everything:
     - `git --version`
     - `python --version` (or python3)
     - `ffmpeg -version | head -1`
     - `yt-dlp --version`
     - `whisper --help | head -3`
     - List ~/.claude/skills/ and confirm these five folders exist:
       reel-start, voice-setup, reel-grab, reel-decode, reel-adapt

9. Print a short summary of what you installed vs what was already present,
   then remind me to fully quit and reopen Claude Code so the new skills load.
````

After reopening Claude Code, type `/reel-start` to see the menu.

---

## Your first time

Run `/voice-setup`. It's a 5-minute interview that captures how you actually talk so every script sounds like you, not a template.

Then paste any Instagram reel URL and run `/reel-grab`.

---

## Pipeline

```
URL or uploaded video
        ↓
   /reel-grab        downloads, transcribes, extracts frames
        ↓
   /reel-decode      storyboard + why it works + 3 questions
        ↓
   (answer questions)
        ↓
   /reel-adapt       script + shot breakdown + production storyboard
```

---

## Output files

Everything saves to `~/reel-engine/Reels/Videos/`:

| File | What it is |
|---|---|
| `Author - Title (ReelID).mp4` | Original video |
| `Author - Title (ReelID).srt` | Transcription |
| `frames_Author/` | Extracted frames (1fps) |
| `Author - Title (ReelID) - storyboard.md` | Full analysis |
| `Author - Title (ReelID) - adapted - Product.md` | Your adapted script + storyboard |

---

## Update

```bash
cd ~/reel-engine
git pull
pip install -r requirements.txt --upgrade
cp -r skills/* ~/.claude/skills/   # on Windows: use File Explorer or xcopy
```

Restart Claude Code.

---

## Uninstall

```bash
rm -rf ~/reel-engine
rm -rf ~/.claude/skills/reel-start ~/.claude/skills/voice-setup ~/.claude/skills/reel-grab ~/.claude/skills/reel-decode ~/.claude/skills/reel-adapt
```

On Windows, delete `%USERPROFILE%\reel-engine` and the five skill folders inside `%USERPROFILE%\.claude\skills`.

---

## Troubleshooting

**"command not found: whisper / yt-dlp"**
→ `pip install -r ~/reel-engine/requirements.txt` again. If `pip` isn't found, install Python 3.8+ and make sure it's in your PATH.

**"missing required tools: ffmpeg"**
→ Install ffmpeg per the Install step. On Windows with winget, restart your shell after install so PATH picks it up.

**"could not fetch reel ID"**
→ The reel is private, deleted, or Instagram is rate-limiting you. Wait a few minutes or try another reel.

**Whisper appears stuck on first run**
→ It's downloading the model (~150MB). One-time only.

**Skills don't show up after install**
→ Fully quit and reopen Claude Code. Confirm the five skill folders exist in `~/.claude/skills/`.

**Windows: script fails with `\r` errors**
→ `.gitattributes` enforces LF line endings. If you edited the script with a Windows editor, re-clone.

---

## Privacy

- `VOICE.md` (your voice profile) is in `.gitignore` and **never committed**.
- Downloaded reels live in `~/reel-engine/Reels/` and are also gitignored.
- The repo ships with `VOICE.template.md` — an empty template. `/voice-setup` copies it to `VOICE.md` on first run.
- Nothing is sent to any third party beyond the tools you already use: Anthropic (Claude), OpenAI Whisper (runs locally), yt-dlp (Instagram).

---

## FAQ

**Does Whisper run locally?**
Yes. The `base` model (~150MB) is pinned in the script. Your audio never leaves your machine.

**Can I use this on TikTok / YouTube Shorts?**
The pipeline script validates the URL as Instagram only. For other sources, upload the video file and use Mode B in `/reel-grab`.

**Can I use a bigger Whisper model?**
Edit `scripts/transcribe_reel.sh` and change `--model base` to `small`, `medium`, or `large`. Bigger = slower + more accurate.

**Does this post for me?**
No. It gives you a ready-to-shoot script + storyboard. You film, edit, and post.

---

## License

MIT
