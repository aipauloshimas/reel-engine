# reel-engine

Analyze any Instagram reel frame-by-frame, extract exactly why it works, and adapt it for your product — with a spoken script, shot-by-shot breakdown, and full production storyboard.

Built by [shimas](https://github.com/aipauloshimas).

> **Only install from this repo** — `github.com/aipauloshimas/reel-engine`. If you see a different URL, don't paste the install block.

---

## What it does

Seven Claude Code skills that work together:

| Skill | What it does |
|---|---|
| `/reel-start` | Orientation menu. Run this if you're unsure where to begin. |
| `/voice-setup` | 5-minute interview to discover your on-camera voice. Run once. |
| `/reel-scout` | Scans a creator (or a list) for viral outliers in the last 30 days. Usage: `/reel-scout @handle` or `/reel-scout creators.txt`. |
| `/reel-grab` | Downloads a reel from a URL (or transcribes one you upload). Extracts frames at 1fps. Detects whether the reel is spoken or text-overlay. |
| `/reel-decode` | Analyzes every frame. Produces a storyboard + persuasion breakdown + 3 targeted questions. |
| `/reel-adapt` | Takes your answers and writes an adapted script, shot-by-shot breakdown, and full production storyboard. |
| `/reel-doctor` | Re-checks and repairs system dependencies (Python, ffmpeg, yt-dlp, whisper, gallery-dl). Useful if a skill complains about a missing tool. |

---

## Requirements

Only one: [Claude Code](https://claude.ai/code) with your Anthropic API key configured.

The install below handles everything else — Git, Python, ffmpeg, Whisper, yt-dlp, and copying the skills — and only installs what you're actually missing.

---

## Before you start

1. Install [Claude Code](https://claude.ai/code) and sign in — a Claude Pro/Max subscription or an Anthropic API key both work (~2 min). reel-engine doesn't add any extra cost: every command runs inside your Claude Code session, billed to whatever account you already use. No separate API bill from this tool.
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

Execute all STEPs below in order without pausing to ask me "want me to continue?"
between them. Only stop if a step fails or if a STEP explicitly tells you to
stop and wait for me. Narrate progress as you go; don't narrate plans.

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
requirements.txt inside, tell me "resume mode" and skip STEP 4 (clone). All
other steps are idempotent. Run `git -C ~/reel-engine pull` before
continuing so any repo updates come down.
If ~/reel-engine/ exists WITHOUT a .git folder (e.g. downloaded as a ZIP),
tell me — I may want to rename it and clone fresh. Don't auto-delete.
If ~/reel-engine/ has a .git folder BUT requirements.txt is missing (partial
clone from a previous failed install), tell me and recommend I run
`rm -rf ~/reel-engine` and re-paste this install block. Don't auto-delete.

STEP 1 — Git.
Run `git --version`. If missing:
  - macOS:   brew install git
  - Linux:   use the distro's package manager (apt / dnf / pacman)
  - Windows: winget install --id Git.Git -e
On Windows: after installing Git, tell me to fully quit Claude Code (right-click
the taskbar icon → Quit — closing the window alone is not enough), reopen it
from Git Bash (Start menu → "Git Bash"), and re-paste this install block.
Don't continue in the current shell — Git Bash won't activate mid-session.
Resume mode (STEP 0) will pick up where we left off.

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
(Skip if resume mode.) Run exactly:
    git clone https://github.com/aipauloshimas/reel-engine.git ~/reel-engine
Do not substitute any other URL — the canonical source is
github.com/aipauloshimas/reel-engine.

STEP 5 — Python dependencies.
Run: pip install --user -r ~/reel-engine/requirements.txt
(Use --user to avoid PEP 668 "externally-managed-environment" errors on modern
macOS/Linux.) This installs openai-whisper and yt-dlp. Whisper pulls in ~2 GB
of PyTorch + its own model cache. Warn me before running that this download
can take 5–15 minutes on a normal connection, and narrate progress every
minute or two so I don't think it froze.

STEP 5b — Fix PATH for whisper and yt-dlp.
After pip installs, check whether `whisper --version` and `yt-dlp --version`
work. If either says "command not found", the pip user-scripts folder is not
on PATH yet. Fix it automatically:
  - macOS/Linux: add `export PATH="$HOME/.local/bin:$PATH"` to ~/.zshrc or
    ~/.bashrc, then run `source ~/.bashrc` (or ~/.zshrc).
  - Windows (Git Bash): find the scripts folder with:
      python -c "import site; print(site.USER_BASE + '\\Scripts')"
    Add it to ~/.bashrc:
      echo 'export PATH="<output from above>:$PATH"' >> ~/.bashrc
      source ~/.bashrc
    Also check whether ffmpeg is missing from PATH and fix it the same way
    using the Gyan.FFmpeg install path from STEP 3.
After sourcing, re-run `whisper --version` and `yt-dlp --version` to confirm.
Tell me what you did and whether they're working now.

STEP 6 — Install the skills.
Copy exactly these seven folders from ~/reel-engine/skills/ into ~/.claude/skills/:
reel-start, voice-setup, reel-scout, reel-grab, reel-decode, reel-adapt, reel-doctor.
Don't glob or copy anything else. Create ~/.claude/skills/ if it doesn't exist.
Overwrite only those seven folders if they already exist from a prior install.

Concrete commands (use Git Bash on Windows):
    mkdir -p ~/.claude/skills
    for s in reel-start voice-setup reel-scout reel-grab reel-decode reel-adapt reel-doctor; do
        rm -rf ~/.claude/skills/$s
        cp -R ~/reel-engine/skills/$s ~/.claude/skills/$s
    done

STEP 7 — Verify everything.
Run each of these and report whether they produced a version/help string
(don't paste the full output):
  - git --version
  - python --version  (or python3)
  - ffmpeg -version
  - yt-dlp --version
  - gallery-dl --version
  - python -c "import whisper; print(whisper.__version__)"
    (Don't use `whisper --help` on Windows — its help text contains a
    Unicode character that crashes on cp1252 terminals. The import check
    above is equivalent and cross-platform.)
Then list ~/.claude/skills/ and confirm these seven folders exist:
  reel-start, voice-setup, reel-scout, reel-grab, reel-decode, reel-adapt, reel-doctor

STEP 8 — Summary + restart reminder.
Print a short table: each dependency, whether it was already installed or
newly installed, and its version. Then print this message in bold, as a
standalone block, so I can't miss it:

    ****************************************************************
    *  STOP. You must fully quit Claude Code and reopen it before   *
    *  running any /reel-* command.                                 *
    *  Closing the window is NOT enough — the app must exit         *
    *  completely. Right-click the Claude Code icon in your         *
    *  taskbar/dock and choose Quit, or use your OS quit shortcut.  *
    *  Then reopen. The skills won't load otherwise.                *
    ****************************************************************
````

After you fully quit and reopen Claude Code, type `/reel-start` to see the menu.

---

## Your first time

Run `/voice-setup`. It's a 5-minute interview that captures how you actually talk so every script sounds like you, not a template. You can say "skip" to any question.

Then paste any Instagram reel URL and run `/reel-grab`.

---

## First scout run

`/reel-scout` needs access to your browser's Instagram cookies — Instagram blocks anonymous profile scraping. The first time you run it, Claude will ask which browser you're logged into (chrome / firefox / edge / opera / brave) and save your choice to `~/reel-engine/scout.conf`.

Under the hood, scout uses **gallery-dl** (not yt-dlp) to enumerate reels — yt-dlp's Instagram user extractor is currently broken upstream, while gallery-dl's is actively maintained. A tiny Python wrapper (`scripts/scout_fetch.py`) monkey-patches gallery-dl to preserve `play_count`, which gallery-dl drops by default. The wrapper and gallery-dl are both installed by STEP 5 (`pip install --user -r requirements.txt`).

**Chrome-family caveat (Windows):** Chrome, Edge, Opera, and Brave lock their cookie database while running. Before each scout run on those browsers, close all browser windows (including background processes in the system tray). The scout finishes in seconds, then you can reopen. **Firefox doesn't have this limitation** — if it bothers you, log into Instagram on Firefox and set `BROWSER=firefox`.

**Fallback:** if `--cookies-from-browser` fails (e.g. Chrome app-bound encryption), export cookies to `~/reel-engine/cookies.txt` using a browser extension like "Get cookies.txt LOCALLY". The script will use that file automatically if no `scout.conf` is found.

---

## Pipeline

```
(optional) /reel-scout @handle   find outlier reels in the last 30 days
        ↓
URL or uploaded video
        ↓
   /reel-grab        downloads, transcribes, extracts frames, detects spoken vs text-overlay
        ↓
   /reel-decode      storyboard + why it works + 3 questions
        ↓
   (answer questions)
        ↓
   /reel-adapt       script + shot breakdown + production storyboard
                     (output format switches automatically for text-overlay reels)
```

---

## Output files

Everything saves to `~/reel-engine/Reels/Videos/`:

| File | What it is |
|---|---|
| `Author - Title (ReelID).mp4` | Original video |
| `Author - Title (ReelID).srt` | Transcription |
| `Author - Title (ReelID).meta.json` | Caption + detected content mode (spoken vs text-overlay) |
| `frames_Author/` | Extracted frames (1fps) — `Author` with spaces replaced by underscores |
| `Author - Title (ReelID) - storyboard.md` | Full analysis |
| `Author - Title (ReelID) - adapted - Product.md` | Your adapted script + storyboard |

`Title` is the first spoken line of the reel, truncated to 50 characters.

---

## Troubleshooting

**Skills don't show up after install**
→ You didn't fully quit Claude Code. Closing the window isn't enough — the app must exit completely. Right-click the Claude Code icon in your taskbar or dock and choose Quit, then reopen. Confirm the seven skill folders exist in `~/.claude/skills/`.

**"command not found: whisper / yt-dlp"**
→ The install ran `pip install --user`, which puts scripts in a per-user folder that isn't always on PATH. Add the right folder to your PATH and reopen the shell:
  - macOS/Linux: add `~/.local/bin` to PATH (e.g. `export PATH="$HOME/.local/bin:$PATH"` in `~/.zshrc` or `~/.bashrc`)
  - Windows (Git Bash): find the folder with `python -c "import site; print(site.USER_BASE + '\\Scripts')"`, then add it to PATH in your `~/.bashrc`, e.g. `export PATH="$APPDATA/Python/Python312/Scripts:$PATH"` (replace `312` with your actual version)
If that doesn't fix it, ask Claude Code to re-run the reel-engine install.

**"missing required tools: ffmpeg"**
→ Ask Claude Code to re-run the reel-engine install. On Windows, open a fresh Git Bash window after install.

**"could not fetch a valid reel ID"**
→ The reel is private, deleted, rate-limited, or the URL isn't a reel/post/TV link. Wait a few minutes or try another reel.

**"a file with the canonical name already exists"**
→ You've already processed that reel. The error message prints the exact `rm` command — copy-paste it into Git Bash. If you prefer a file explorer, the files live in `~/reel-engine/Reels/Videos/`.

**Whisper appears stuck on first run**
→ Two possible waits: (a) during install, pip is downloading PyTorch (~2GB, 5–15 min). (b) on your first `/reel-grab`, Whisper downloads the model (~150MB, 1–2 min). Both are one-time.

**pip fails with "externally-managed-environment" (PEP 668)**
→ The install uses `pip install --user` to avoid this. If you're running manually, add `--user`: `pip install --user -r requirements.txt`.

**Windows: script fails with `\r` errors or "command not found" in Git Bash**
→ You're probably running from PowerShell/CMD instead of Git Bash. Open Git Bash (Start menu → "Git Bash"). If that doesn't fix it, delete `~/reel-engine/` and paste the install block again.

**I downloaded the repo as a ZIP and resume mode doesn't work**
→ Rename the existing folder (e.g. `mv ~/reel-engine ~/reel-engine-zip`) and paste the install block again. The clone step will fetch a proper repo.

**Install failed halfway — can I retry?**
→ Yes. Paste the install block again. Step 0 detects the existing folder and runs in resume mode.

---

## Update

Easiest: paste the install block again. Step 0 detects the existing install and runs in resume mode (runs `git pull`, re-installs pip deps if missing, re-copies skills). Resume mode does **not** upgrade pinned Python packages — if you want newer Whisper or yt-dlp, use the manual commands below.

Manually (Git Bash on Windows):
```bash
cd ~/reel-engine
git pull
pip install --user -r requirements.txt --upgrade
for s in reel-start voice-setup reel-scout reel-grab reel-decode reel-adapt reel-doctor; do
    rm -rf ~/.claude/skills/$s
    cp -R ~/reel-engine/skills/$s ~/.claude/skills/$s
done
```

Fully quit and reopen Claude Code after updating.

---

## Uninstall

Git Bash on Windows, or native shell on macOS/Linux:
```bash
rm -rf ~/reel-engine
for s in reel-start voice-setup reel-scout reel-grab reel-decode reel-adapt reel-doctor; do
    rm -rf ~/.claude/skills/$s
done
```

Python packages stay installed — they're useful outside this project. Remove them with `pip uninstall openai-whisper yt-dlp` if you want.

---

## Privacy

- `VOICE.md` (your voice profile) is in `.gitignore` and **never committed**.
- Downloaded reels live in `~/reel-engine/Reels/` and are also gitignored.
- The repo ships with `VOICE.template.md` — an empty template. `/voice-setup` copies it to `VOICE.md` on first run.
- Whisper runs locally, so your audio never leaves the machine during transcription. yt-dlp talks to Instagram to fetch the reel.
- When you run `/reel-decode` or `/reel-adapt`, Claude Code sends the extracted frames and transcript to Anthropic for analysis — that's how the storyboard and script get generated. This is the same Anthropic request path every Claude Code session uses; no third party beyond Anthropic is involved.

---

## FAQ

**Does Whisper run locally?**
Yes. The `base` model (~150MB) is pinned in the script. Your audio never leaves your machine.

**Can I use this on TikTok / YouTube Shorts?**
The pipeline script validates the URL as Instagram only. For other sources, drop the video file into `~/reel-engine/Reels/Videos/` and use Mode B in `/reel-grab` — Mode B skips the yt-dlp download and runs Whisper + frame extraction directly on the file you provide, so any video works.

**Can I use a bigger Whisper model?**
For Mode A (URL downloads) edit `~/reel-engine/scripts/transcribe_reel.sh` and change `--model base` to `small`, `medium`, or `large`. For Mode B (local uploads) the model is chosen in the command `/reel-grab` runs, so tell the skill which model you want. Bigger = slower + more accurate.

**Does this post for me?**
No. It gives you a ready-to-shoot script + storyboard. You film, edit, and post.

**My install keeps saying "password prompt"**
Normal on macOS/Linux — Homebrew and apt need sudo for some installs. You paste your computer password, not any GitHub or API key.

---

## License

MIT
