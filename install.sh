#!/usr/bin/env bash
# reel-engine bootstrap — single-pass installer.
#
# Run from a cloned repo:
#   bash install.sh
#
# Run direct (one-liner):
#   curl -sSL https://raw.githubusercontent.com/aipauloshimas/reel-engine/main/install.sh | bash
#
# The script is idempotent. Re-running it on an already-installed system is safe.
#
# What it does:
#   1. Detect OS (macOS / Linux / Windows-Git-Bash).
#   2. Install Git, Python 3.10+, ffmpeg if missing (brew / apt-or-dnf-or-pacman / winget).
#   3. On Windows, use absolute paths to the just-installed binaries — no PATH refresh dance.
#   4. Clone the repo to ~/reel-engine (or git pull if already there).
#   5. pip install --user the Python deps.
#   6. Persist user-scripts folder into ~/.bashrc / ~/.zshrc so whisper / yt-dlp / gallery-dl stay on PATH.
#   7. Copy the seven skills from ~/reel-engine/skills/ into ~/.claude/skills/.
#   8. Print a status table and tell the user to fully quit Claude Code.

set -euo pipefail

REPO_URL="https://github.com/aipauloshimas/reel-engine.git"
REPO_DIR="$HOME/reel-engine"
SKILLS_DIR="$HOME/.claude/skills"
SKILLS=(reel-start voice-setup reel-scout reel-grab reel-decode reel-adapt reel-doctor)

# ────────────────────────────────────────────────────────────────────────────
# Logging helpers
# ────────────────────────────────────────────────────────────────────────────
log()  { printf "→ %s\n" "$*"; }
warn() { printf "! %s\n" "$*" >&2; }
fail() { printf "✘ %s\n" "$*" >&2; exit 1; }

# ────────────────────────────────────────────────────────────────────────────
# OS detection
# ────────────────────────────────────────────────────────────────────────────
case "$(uname -s)" in
    Darwin*) OS=macos ;;
    Linux*)  OS=linux ;;
    MINGW*|MSYS*|CYGWIN*) OS=windows ;;
    *) fail "Unsupported OS: $(uname -s). reel-engine supports macOS, Linux, and Windows (Git Bash)." ;;
esac
log "OS detected: $OS"

# ────────────────────────────────────────────────────────────────────────────
# Linux distro family detection (apt / dnf / pacman)
# ────────────────────────────────────────────────────────────────────────────
LINUX_PM=""
if [ "$OS" = "linux" ]; then
    if command -v apt-get >/dev/null 2>&1; then LINUX_PM=apt
    elif command -v dnf >/dev/null 2>&1; then LINUX_PM=dnf
    elif command -v pacman >/dev/null 2>&1; then LINUX_PM=pacman
    else fail "No supported Linux package manager found (apt / dnf / pacman)."
    fi
fi

# ────────────────────────────────────────────────────────────────────────────
# Helpers — version checks
# ────────────────────────────────────────────────────────────────────────────
have() { command -v "$1" >/dev/null 2>&1; }

# Returns 0 if `python3` or `python` reports >= 3.10
python_ok() {
    local cmd
    for cmd in python3 python; do
        if have "$cmd"; then
            "$cmd" -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' 2>/dev/null && return 0
        fi
    done
    return 1
}

# ────────────────────────────────────────────────────────────────────────────
# macOS — Homebrew
# ────────────────────────────────────────────────────────────────────────────
ensure_brew() {
    if have brew; then return; fi
    log "Installing Homebrew (will prompt for sudo password)…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    have brew || fail "brew installed but not on PATH. Open a fresh terminal and re-run install.sh."
}

# ────────────────────────────────────────────────────────────────────────────
# Windows — winget + absolute-path PATH augmentation
# ────────────────────────────────────────────────────────────────────────────
winget_install() {
    local id="$1"
    log "winget install $id"
    # User-scope flags + accept agreements to avoid interactive prompts.
    # UAC may still appear if the package needs elevation — that's a Windows reality.
    winget install --id "$id" -e --silent \
        --accept-package-agreements --accept-source-agreements \
        --scope user 2>&1 || \
    winget install --id "$id" -e --silent \
        --accept-package-agreements --accept-source-agreements 2>&1
}

# After winget installs Git, locate it deterministically and add to PATH for THIS process.
# Git's installer reliably uses C:\Program Files\Git on every modern Windows.
windows_path_git() {
    local candidates=(
        "/c/Program Files/Git/bin"
        "/c/Program Files/Git/cmd"
        "/c/Program Files (x86)/Git/bin"
        "/c/Program Files (x86)/Git/cmd"
    )
    local p
    for p in "${candidates[@]}"; do
        if [ -x "$p/git.exe" ] || [ -x "$p/git" ]; then
            export PATH="$p:$PATH"
        fi
    done
    have git
}

# Python via winget (Python.Python.3.12) installs to %LOCALAPPDATA%\Programs\Python\Python312
windows_path_python() {
    local user_dir="/c/Users/${USERNAME:-${USER:-}}"
    [ -z "${USERNAME:-${USER:-}}" ] && user_dir="$HOME"
    local candidates=(
        "$user_dir/AppData/Local/Programs/Python/Python313"
        "$user_dir/AppData/Local/Programs/Python/Python312"
        "$user_dir/AppData/Local/Programs/Python/Python311"
        "$user_dir/AppData/Local/Programs/Python/Python310"
    )
    local p
    for p in "${candidates[@]}"; do
        if [ -x "$p/python.exe" ]; then
            export PATH="$p:$p/Scripts:$PATH"
        fi
    done
    python_ok
}

# ffmpeg via winget (Gyan.FFmpeg) lives under WinGet\Packages\Gyan.FFmpeg_*
windows_path_ffmpeg() {
    local user_dir="/c/Users/${USERNAME:-${USER:-}}"
    [ -z "${USERNAME:-${USER:-}}" ] && user_dir="$HOME"
    local found
    found="$(find "$user_dir/AppData/Local/Microsoft/WinGet/Packages" \
        -name "ffmpeg.exe" -path "*Gyan.FFmpeg*" 2>/dev/null | head -1 || true)"
    if [ -n "$found" ]; then
        export PATH="$(dirname "$found"):$PATH"
    fi
    have ffmpeg
}

# Add a directory to PATH inside the user's shell rc so it persists across sessions.
# Idempotent — won't duplicate the line.
persist_path() {
    local dir="$1" rc
    [ -z "$dir" ] && return
    case "$OS" in
        macos|linux)
            for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
                [ -f "$rc" ] || continue
                grep -qF "export PATH=\"$dir:\$PATH\"" "$rc" || \
                    printf '\n# reel-engine\nexport PATH="%s:$PATH"\n' "$dir" >> "$rc"
            done
            ;;
        windows)
            for rc in "$HOME/.bashrc"; do
                [ -f "$rc" ] || touch "$rc"
                grep -qF "export PATH=\"$dir:\$PATH\"" "$rc" || \
                    printf '\n# reel-engine\nexport PATH="%s:$PATH"\n' "$dir" >> "$rc"
            done
            ;;
    esac
}

# ────────────────────────────────────────────────────────────────────────────
# 1. Git
# ────────────────────────────────────────────────────────────────────────────
GIT_STATUS="already-installed"
if ! have git; then
    log "Git missing. Installing…"
    case "$OS" in
        macos)
            ensure_brew
            brew install git
            ;;
        linux)
            case "$LINUX_PM" in
                apt)    sudo apt-get update && sudo apt-get install -y git ;;
                dnf)    sudo dnf install -y git ;;
                pacman) sudo pacman -Sy --noconfirm git ;;
            esac
            ;;
        windows)
            winget_install Git.Git || fail "Git install failed. If UAC was denied, re-run from an admin PowerShell or install Git manually from https://git-scm.com/download/win"
            windows_path_git || fail "Git installed but not detectable. Restart Claude Code and re-run install.sh."
            ;;
    esac
    have git || fail "Git install completed but \`git\` is not on PATH."
    GIT_STATUS="newly-installed"
fi
log "git: $(git --version)"

# ────────────────────────────────────────────────────────────────────────────
# 2. Python 3.10+
# ────────────────────────────────────────────────────────────────────────────
PYTHON_STATUS="already-installed"
if ! python_ok; then
    log "Python 3.10+ missing. Installing…"
    case "$OS" in
        macos)
            ensure_brew
            brew install python@3.12
            ;;
        linux)
            case "$LINUX_PM" in
                apt)    sudo apt-get install -y python3 python3-pip python3-venv ;;
                dnf)    sudo dnf install -y python3 python3-pip ;;
                pacman) sudo pacman -Sy --noconfirm python python-pip ;;
            esac
            ;;
        windows)
            winget_install Python.Python.3.12 || fail "Python install failed."
            windows_path_python || fail "Python installed but not detectable at expected location."
            ;;
    esac
    python_ok || fail "Python 3.10+ install completed but \`python\`/\`python3\` not on PATH or version too old."
    PYTHON_STATUS="newly-installed"
fi

# Pick the right python command for the rest of this script
PY=""
for cmd in python3 python; do
    if have "$cmd" && "$cmd" -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' 2>/dev/null; then
        PY="$cmd"; break
    fi
done
[ -n "$PY" ] || fail "No usable Python interpreter found after install."
log "python: $($PY --version)"

# Pick pip
PIP=""
for cmd in pip3 pip; do
    if have "$cmd"; then PIP="$cmd"; break; fi
done
if [ -z "$PIP" ]; then
    "$PY" -m ensurepip --user >/dev/null 2>&1 || true
    PIP="$PY -m pip"
fi
log "pip: $($PIP --version 2>&1 | head -1)"

# ────────────────────────────────────────────────────────────────────────────
# 3. ffmpeg
# ────────────────────────────────────────────────────────────────────────────
FFMPEG_STATUS="already-installed"
if ! have ffmpeg; then
    log "ffmpeg missing. Installing…"
    case "$OS" in
        macos)
            ensure_brew
            brew install ffmpeg
            ;;
        linux)
            case "$LINUX_PM" in
                apt)    sudo apt-get install -y ffmpeg ;;
                dnf)    sudo dnf install -y ffmpeg ;;
                pacman) sudo pacman -Sy --noconfirm ffmpeg ;;
            esac
            ;;
        windows)
            winget_install Gyan.FFmpeg || fail "ffmpeg install failed."
            windows_path_ffmpeg || fail "ffmpeg installed but not detectable at expected location."
            ;;
    esac
    have ffmpeg || fail "ffmpeg install completed but \`ffmpeg\` is not on PATH."
    FFMPEG_STATUS="newly-installed"
fi
log "ffmpeg: $(ffmpeg -version | head -1)"

# ────────────────────────────────────────────────────────────────────────────
# 4. Clone (or update) the repo
# ────────────────────────────────────────────────────────────────────────────
if [ -d "$REPO_DIR/.git" ]; then
    log "Repo already at $REPO_DIR — git pull"
    git -C "$REPO_DIR" pull --ff-only || warn "git pull failed; continuing with existing checkout"
elif [ -d "$REPO_DIR" ]; then
    fail "$REPO_DIR exists but isn't a git checkout. Move it aside and re-run."
else
    log "Cloning $REPO_URL → $REPO_DIR"
    git clone --depth 1 "$REPO_URL" "$REPO_DIR"
fi

# ────────────────────────────────────────────────────────────────────────────
# 5. Python deps
# ────────────────────────────────────────────────────────────────────────────
log "Installing Python deps (this is the slow step — Whisper pulls ~2 GB of PyTorch)…"
$PIP install --user -r "$REPO_DIR/requirements.txt"

# ────────────────────────────────────────────────────────────────────────────
# 6. Persist user-scripts directory on PATH (so whisper / yt-dlp / gallery-dl resolve)
# ────────────────────────────────────────────────────────────────────────────
USER_BASE="$($PY -c 'import site; print(site.USER_BASE)')"
case "$OS" in
    macos|linux) USER_SCRIPTS="$USER_BASE/bin" ;;
    windows)     USER_SCRIPTS="$USER_BASE/Scripts" ;;
esac
if [ -d "$USER_SCRIPTS" ]; then
    export PATH="$USER_SCRIPTS:$PATH"
    persist_path "$USER_SCRIPTS"
    log "User scripts dir on PATH: $USER_SCRIPTS"
fi

# ────────────────────────────────────────────────────────────────────────────
# 7. Copy skills into ~/.claude/skills/
# ────────────────────────────────────────────────────────────────────────────
mkdir -p "$SKILLS_DIR"
for s in "${SKILLS[@]}"; do
    src="$REPO_DIR/skills/$s"
    dst="$SKILLS_DIR/$s"
    [ -d "$src" ] || fail "Skill source missing in repo: $src"
    rm -rf "$dst"
    cp -R "$src" "$dst"
    log "Installed skill: $s"
done

# ────────────────────────────────────────────────────────────────────────────
# 8. Final verification + summary
# ────────────────────────────────────────────────────────────────────────────
echo
echo "──────────────────────────────────────────────"
echo "reel-engine install summary"
echo "──────────────────────────────────────────────"
printf "%-12s  %s\n" "git"    "$GIT_STATUS    $(git --version)"
printf "%-12s  %s\n" "python" "$PYTHON_STATUS    $($PY --version)"
printf "%-12s  %s\n" "ffmpeg" "$FFMPEG_STATUS    $(ffmpeg -version | head -1 | sed 's/ Copyright.*//')"

# Verify the python tools resolved
for tool in yt-dlp gallery-dl; do
    if have "$tool"; then
        printf "%-12s  %s\n" "$tool" "ok    $($tool --version 2>&1 | head -1)"
    else
        printf "%-12s  %s\n" "$tool" "MISSING from PATH (try a fresh shell)"
    fi
done

# Whisper: import-based check (works on Windows cp1252 terminals where `whisper --help` crashes)
if "$PY" -c 'import whisper; print(whisper.__version__)' >/dev/null 2>&1; then
    printf "%-12s  %s\n" "whisper" "ok    $($PY -c 'import whisper; print(whisper.__version__)')"
else
    printf "%-12s  %s\n" "whisper" "import FAILED — pip install may not have completed"
fi

printf "%-12s  %d skills in %s\n" "skills" "$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)" "$SKILLS_DIR"

echo
cat <<'EOF'
══════════════════════════════════════════════════════════════════
  NEXT STEP — fully quit Claude Code, then reopen.

  Closing the window is NOT enough. The app must exit completely:
    • Windows / Linux: right-click the Claude Code icon in the
      taskbar/system tray → Quit (or use Alt+F4 and confirm Quit).
    • macOS: ⌘Q from the menu bar, or Quit from the dock icon.

  After reopening, type /reel-start to see the menu.
══════════════════════════════════════════════════════════════════
EOF
