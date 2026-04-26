---
name: reel-doctor
description: Check and install reel-engine system dependencies (Python 3.10+, ffmpeg, yt-dlp, openai-whisper, gallery-dl), plus drop the helper scripts into ~/reel-engine/scripts/. Run this once after copying skills/reel-* into ~/.claude/skills/, or any time a reel-* skill complains about a missing tool.
---

# /reel-doctor — Bootstrap reel-engine dependencies

You are running a one-shot system check + install. The user just installed the reel-engine skills and needs the underlying CLIs available before any /reel-* skill will work.

## Rules

- Detect the OS first. Don't assume.
- For every dependency, run the version check FIRST. Only install what's missing. Never overwrite working installs.
- On Windows, all shell steps run in **Git Bash**. If the user is in PowerShell or CMD, stop and tell them to reopen in Git Bash. Don't try to translate commands.
- Stop and tell the user if any step fails. Don't invent workarounds.
- Narrate progress as you go. Don't narrate plans.

## STEP 0 — Detect OS

Run `uname -s` (works in Git Bash, macOS, Linux).
- `Darwin` → macOS
- `Linux` → Linux
- `MINGW*` / `MSYS*` / `CYGWIN*` → Windows (Git Bash)
- Anything else → stop and ask the user what OS they're on.

If Windows but NOT Git Bash (e.g. `$SHELL` is empty or PowerShell), stop:
> "Open Git Bash (Start menu → 'Git Bash') and re-run `/reel-doctor` from there. PowerShell and CMD won't work for the install steps."

## STEP 1 — Check + install Python 3.10+

Run `python3 --version` (fall back to `python --version`). Need 3.10 or higher (Whisper requires it).

If missing or too old:
- macOS: `brew install python@3.12`
- Linux: distro package manager (e.g. `sudo apt install python3.12 python3-pip`)
- Windows: `winget install --id Python.Python.3.12 -e`

Verify pip: `pip3 --version` or `pip --version`.

## STEP 2 — Check + install ffmpeg

Run `ffmpeg -version`. If missing:
- macOS: `brew install ffmpeg`
- Linux: `sudo apt install ffmpeg`
- Windows: `winget install --id Gyan.FFmpeg -e`

On Windows, after install, tell the user to open a fresh Git Bash window so PATH refreshes — then re-run `/reel-doctor` to continue.

## STEP 3 — Check + install Python packages

Run these checks:
- `yt-dlp --version`
- `gallery-dl --version`
- `python3 -c "import whisper; print(whisper.__version__)"` (don't use `whisper --help` on Windows — Unicode crash on cp1252 terminals)

For any missing, install with:
```
pip install --user "openai-whisper>=20240930" "yt-dlp>=2025.01.01" "gallery-dl>=1.31.0"
```

Warn the user before running this: Whisper pulls in ~2 GB of PyTorch + dependencies. The download takes 5-15 minutes on a normal connection. Narrate progress every 1-2 minutes so they don't think it froze.

## STEP 4 — Fix PATH (if needed)

After `pip install --user`, the scripts (`whisper`, `yt-dlp`, `gallery-dl`) may not be on PATH yet.

Re-run the version checks from STEP 3. If any return "command not found":

- **macOS/Linux:** add to `~/.zshrc` or `~/.bashrc`:
  ```
  export PATH="$HOME/.local/bin:$PATH"
  ```
  Then `source ~/.bashrc` (or zshrc) and re-check.

- **Windows (Git Bash):** find the user-scripts folder:
  ```
  python -c "import site; print(site.USER_BASE + '\\Scripts')"
  ```
  Add it to `~/.bashrc`:
  ```
  echo 'export PATH="<output above>:$PATH"' >> ~/.bashrc
  source ~/.bashrc
  ```
  Re-check.

## STEP 5 — Create the user data directory

reel-engine writes downloads, transcripts, and outputs to `~/reel-engine/`. Create the structure if missing:

```
mkdir -p ~/reel-engine/Reels/Videos
mkdir -p ~/reel-engine/outliers
```

The skills assume this layout. Don't substitute another path.

## STEP 6 — Install the helper scripts

reel-engine ships pipeline scripts (`transcribe_reel.sh`, `scout_reels.sh`, `scout_fetch.py`) that the skills shell out to. They live in `~/reel-engine/scripts/`.

Check whether they're already in place:
```
ls ~/reel-engine/scripts/transcribe_reel.sh ~/reel-engine/scripts/scout_reels.sh ~/reel-engine/scripts/scout_fetch.py 2>/dev/null
```

If all three exist, skip the rest of this step.

Otherwise, fetch them by cloning the repo to a temp folder, copying scripts/, and cleaning up:

```
mkdir -p ~/reel-engine/scripts
TMP="$(mktemp -d)"
git clone --depth 1 https://github.com/aipauloshimas/reel-engine "$TMP"
cp "$TMP"/scripts/* ~/reel-engine/scripts/
chmod +x ~/reel-engine/scripts/*.sh
rm -rf "$TMP"
```

Verify:
```
ls -la ~/reel-engine/scripts/
```

Should show three executable files.

## STEP 7 — Cookies setup (deferred to first /reel-scout)

Don't ask about Instagram cookies here. `/reel-scout` handles first-run cookie setup interactively (browser choice → `~/reel-engine/scout.conf` or `~/reel-engine/cookies.txt`).

Just tell the user: "When you run `/reel-scout` for the first time, I'll ask which browser you have Instagram logged into."

## STEP 8 — Final summary

Print a small table. For each tool: status (already installed / newly installed / failed) + version.

Then tell the user:

> "reel-engine is ready. Run `/reel-start` to see the menu, or jump straight to `/reel-scout @creator` to find viral reels."

If anything failed, list it explicitly with a remediation hint and stop.
