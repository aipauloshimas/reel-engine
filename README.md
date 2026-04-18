# reel-engine

Analyze any Instagram reel frame-by-frame, extract exactly why it works, and adapt it for your product — with a spoken script, shot-by-shot breakdown, and full production storyboard.

Built by [shimas](https://github.com/aipauloshimas).

> **Only install from this repo** — `github.com/aipauloshimas/reel-engine`. If you see a different URL, don't paste the install block.

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

## Before you start

1. Install [Claude Code](https://claude.ai/code) and connect it to your Anthropic API key (~2 min).
2. Open Claude Code. You'll see a chat interface.
3. Copy the block in the next section, paste it into Claude Code's chat, and press Enter.
4. The install takes **5 to 20 minutes** depending on what's already on your machine and your internet speed. You may be asked for your password (macOS/Linux) — that's Homebrew or apt.
5. Expect a ~2 GB download for Python + Whisper's ML libraries. That's normal.

---

## Install

**On Windows, use Git Bash (it gets installed automatically). Don't run the install from PowerShell or CMD — paths won't resolve correctly.**

Paste this block into Claude Code exactly:

````
Install reel-engine from https://github.com/aipauloshimas/reel-engine.

Rules for this install:
- Detect my OS first (macOS / Linux / Windows).
- For every dependency, run the version check first. Only install what's
  missing. Never overwrite working installs.
- On Windows, use Git Bash for all subsequent shell steps. If Git Bash isn't
  available yet, install Git first (it includes Git Bash), then re-check.
- On macOS, if Homebrew isn't installed, install it with the official script:
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  Warn me this triggers a password prompt and can take ~5 min and ~1 GB
  (Xcode Command Line Tools). On Apple Silicon, run `eval "$(/opt/homebrew/bin/brew shellenv)"` before using brew.
- On Windows, check `winget --version`. If winget is missing, tell me to
  install "App Installer" from the Microsoft Store, then stop and wait for me.
- Stop and tell me if any step fails. Don't try clever workarounds.

STEP 0 — Resume mode check.
If ~/reel-engine/ already exists AND has a .git folder AND has
requirements.txt inside, tell me "resume mode" and skip step 5 (clone). All
other steps are idempotent. If ~/reel-engine/ exists but isn't a valid
repo, stop and ask me what to do — don't delete anything.

STEP 1 — Git.
Run `git --version`. If missing:
  - macOS:   brew install git
  - Linux:   use the distro's package manager (apt / dnf / pacman)
  - Windows: winget install --id Git.Git -e
On Windows, after installing Git, switch to Git Bash for the rest of the install.

STEP 2 — Python 3.8+.
Run `python --version` then `python3 --version`. Need one that reports 3.8 or
higher. If neither works:
  - macOS:   brew install python
  - Linux:   distro package manager (python3 + python3-pip)
  - Windows: winget install --id Python.Python.3.12 -e
Verify pip works: `pip --version` (or `pip3 --version`).

STEP 3 — ffmpeg.
Run `ffmpeg -version`. If missing:
  - macOS:   brew install ffmpeg
  - Linux:   distro package manager
  - Windows: winget install --id Gyan.FFmpeg -e
On Windows, open a fresh Git Bash shell after install so PATH refreshes.

STEP 4 — Clone the repo.
(Skip if resume mode.) Clone https://github.com/aipauloshimas/reel-engine to
~/reel-engine/ using HTTPS.

STEP 5 — Python dependencies.
Run: pip install --user -r ~/reel-engine/requirements.txt
(Use --user to avoid PEP 668 "externally-managed-environment" errors on modern
macOS/Linux.) This installs openai-whisper and yt-dlp. Whisper pulls in ~2 GB
of PyTorch + its own model cache. Warn me before running that this download
can take 5–15 minutes on a normal connection, and narrate progress every
minute or two so I don't think it froze.

STEP 6 — Install the skills.
Copy every folder inside ~/reel-engine/skills/ into ~/.claude/skills/.
Create the target directory if it doesn't exist. Never overwrite unrelated
skill folders (only overwrite reel-start, voice-setup, reel-grab,
reel-decode, reel-adapt if they already exist from a prior install).

Concrete commands:
  - macOS / Linux / Git Bash:
      mkdir -p ~/.claude/skills
      cp -R ~/reel-engine/skills/. ~/.claude/skills/
  - Windows PowerShell (only if Git Bash isn't an option):
      New-Item -ItemType Directory -Force $env:USERPROFILE\.claude\skills
      Copy-Item -Recurse -Force $env:USERPROFILE\reel-engine\skills\* $env:USERPROFILE\.claude\skills\

STEP 7 — Verify everything.
Run each of these and report the first line of output:
  - git --version
  - python --version  (or python3)
  - ffmpeg -version
  - yt-dlp --version
  - whisper --help
Then list ~/.claude/skills/ and confirm these five folders exist:
  reel-start, voice-setup, reel-grab, reel-decode, reel-adapt

STEP 8 — Summary + restart reminder.
Print a short table: each dependency, whether it was already installed or
newly installed, and its version. Then print this message in bold, as a
standalone block, so I can't miss it:

    ****************************************************************
    *  STOP. Quit Claude Code completely and reopen it before       *
    *  running any /reel-* command. Closing the window is NOT       *
    *  enough — use Cmd+Q (macOS) or Ctrl+Q (Windows/Linux) to      *
    *  fully quit, then reopen. The skills won't load otherwise.    *
    ****************************************************************
````

After you fully quit and reopen Claude Code, type `/reel-start` to see the menu.

---

## Your first time

Run `/voice-setup`. It's a 5-minute interview that captures how you actually talk so every script sounds like you, not a template. You can say "skip" to any question.

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
| `frames_Author/` | Extracted frames (1fps) — `Author` with spaces replaced by underscores |
| `Author - Title (ReelID) - storyboard.md` | Full analysis |
| `Author - Title (ReelID) - adapted - Product.md` | Your adapted script + storyboard |

`Title` is the first spoken line of the reel, truncated to 50 characters.

---

## Update

The easiest way: paste the install block again — it's idempotent (step 0 detects an existing install and runs in resume mode).

Or manually:

**macOS / Linux / Git Bash:**
```bash
cd ~/reel-engine
git pull
pip install --user -r requirements.txt --upgrade
cp -R skills/. ~/.claude/skills/
```

**Windows PowerShell:**
```powershell
cd $env:USERPROFILE\reel-engine
git pull
pip install --user -r requirements.txt --upgrade
Copy-Item -Recurse -Force skills\* $env:USERPROFILE\.claude\skills\
```

Fully quit and reopen Claude Code after updating.

---

## Uninstall

**macOS / Linux / Git Bash:**
```bash
rm -rf ~/reel-engine
rm -rf ~/.claude/skills/reel-start ~/.claude/skills/voice-setup ~/.claude/skills/reel-grab ~/.claude/skills/reel-decode ~/.claude/skills/reel-adapt
```

**Windows PowerShell:**
```powershell
Remove-Item -Recurse -Force $env:USERPROFILE\reel-engine
Remove-Item -Recurse -Force $env:USERPROFILE\.claude\skills\reel-start, $env:USERPROFILE\.claude\skills\voice-setup, $env:USERPROFILE\.claude\skills\reel-grab, $env:USERPROFILE\.claude\skills\reel-decode, $env:USERPROFILE\.claude\skills\reel-adapt
```

Python packages stay installed — they're useful outside this project. Remove them with `pip uninstall openai-whisper yt-dlp` if you want.

---

## Troubleshooting

**Skills don't show up after install**
→ You didn't fully quit Claude Code. Close the window isn't enough — use Cmd+Q (macOS) or Ctrl+Q (Windows/Linux), then reopen. Confirm the five skill folders exist in `~/.claude/skills/`.

**"command not found: whisper / yt-dlp"**
→ Ask Claude Code to re-run the reel-engine install. If that fails, install Python 3.8+ and make sure it's in your PATH.

**"missing required tools: ffmpeg"**
→ Ask Claude Code to re-run the reel-engine install. On Windows, open a fresh Git Bash window after install.

**"could not fetch reel ID"**
→ The reel is private, deleted, or Instagram is rate-limiting. Wait a few minutes or try another reel.

**"a file with the canonical name already exists"**
→ You've already processed that reel. Delete the existing `.mp4` / `.srt` / `storyboard.md` from `~/reel-engine/Reels/Videos/` or pick a different reel.

**Whisper appears stuck on first run**
→ It's downloading the model (~150MB) plus PyTorch (~2GB on first install). Normal. Expect 5–15 min on first run, instant afterward.

**pip fails with "externally-managed-environment" (PEP 668)**
→ The install uses `pip install --user` to avoid this. If you're running manually, add `--user`: `pip install --user -r requirements.txt`.

**Windows: script fails with `\r` errors**
→ You're probably running from PowerShell/CMD instead of Git Bash. Open Git Bash. If that doesn't fix it, delete `~/reel-engine/` and paste the install block again.

**Install failed halfway — can I retry?**
→ Yes. Paste the install block again. Step 0 detects the existing folder and runs in resume mode, picking up where it left off.

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
The pipeline script validates the URL as Instagram only. For other sources, upload the video file and use Mode B in `/reel-grab` — Mode B skips the download script and runs Whisper directly, so any video works.

**Can I use a bigger Whisper model?**
Edit `scripts/transcribe_reel.sh` and change `--model base` to `small`, `medium`, or `large`. Bigger = slower + more accurate.

**Does this post for me?**
No. It gives you a ready-to-shoot script + storyboard. You film, edit, and post.

**My install keeps saying "password prompt"**
Normal on macOS/Linux — Homebrew and apt need sudo for some installs. You paste your computer password, not any GitHub or API key.

---

## License

MIT
