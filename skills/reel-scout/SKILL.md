---
name: reel-scout
description: Scans one or more Instagram creators to find viral outlier reels (5x+ baseline views) posted in the last month. Use when the user runs /reel-scout, asks to find viral videos, check for outliers, or scout creators for reel ideas. Accepts a single @handle, multiple @handles inline, or a text file with one handle per line.
---

# /reel-scout — The Scout

You find the viral outlier reels in a creator's recent output — the ones that performed 5x+ above their baseline. These are the best candidates to decode and adapt.

## Inputs — three accepted forms

1. **Single handle:** `/reel-scout @username`
2. **Multiple handles inline:** `/reel-scout @one @two @three`
3. **File:** `/reel-scout creators.txt` — a path to a text file with one handle per line. Lines starting with `#` are comments.

If the user runs `/reel-scout` alone, ask:
> "Paste the Instagram handle(s) you want me to scout, or give me a path to a `.txt` file with one handle per line."

## First-run setup (one-time)

Before the first scout, check whether `~/reel-engine/scout.conf` or `~/reel-engine/cookies.txt` exists. If **neither** exists, **stop and ask the user once**:

> "To scout Instagram, I need cookies from a logged-in session (Instagram blocks anonymous profile scraping). Pick the most reliable option:
>
> **A) Firefox** — loga no IG no Firefox, me responde `firefox`, e esquece. Funciona consistentemente.
>
> **B) Export manual de cookies** (funciona com qualquer browser, incluindo Chrome/Opera/Edge/Brave):
>   1. Instala a extensão **"Get cookies.txt LOCALLY"** no seu browser
>   2. Abre instagram.com (logado)
>   3. Clica no ícone da extensão → botão **Export** (não "Export All")
>   4. Salva o arquivo como `~/reel-engine/cookies.txt`
>   5. Me responde `cookies`
>
> **Por que não Chrome/Opera/Edge/Brave direto?** Desde meados de 2024, Chrome-family usa App-Bound Encryption (ABE) que bloqueia leitura externa do cookie `sessionid`. Resultado: 401 Unauthorized. A extensão contorna isso.
>
> Qual: `firefox` ou `cookies`?"

When they answer:
- `firefox` → write `~/reel-engine/scout.conf` with `BROWSER=firefox`. Proceed.
- `cookies` → wait until `~/reel-engine/cookies.txt` exists, then proceed (no scout.conf needed).
- If they insist on Chrome-family: accept, warn that it may 401, write `BROWSER=<name>` and tell them to **close all windows of that browser** before running. If it fails, fall back to option B.

**Cookie expiration (option B):** IG `sessionid` dura tecnicamente ~1 ano, mas IG pode invalidar antes (logout, troca de senha, atividade suspeita). Esperar 30–90 dias antes de precisar re-exportar. Se o scout começar a dar 401 depois de funcionar, re-exporte o `cookies.txt`.

**Do not ask about profiles.** Most users have one profile. If it turns out to be the wrong one, the "not logged in" error handler below will recover.

## Running the script

For each handle:
```bash
bash ~/reel-engine/scripts/scout_reels.sh <handle> 30
```

**Multiple handles:** call once per handle, with a 2-second gap between calls (the script also enforces `--sleep-requests 1` per-request internally).

**From a file:**
```bash
while IFS= read -r line; do
    [[ -z "${line// }" || "$line" =~ ^[[:space:]]*# ]] && continue
    handle="${line#@}"
    handle="${handle// /}"
    bash ~/reel-engine/scripts/scout_reels.sh "$handle" 30
    sleep 2
done < creators.txt
```

Print the script's stdout verbatim — the raw report is the deliverable.

## Exit codes and what to do

The script distinguishes failure modes so you can give the user a precise next step instead of "something broke."

| Code | Meaning | What you say / do |
|---|---|---|
| 0 | Success | Print the report. Move to next handle if looping. |
| 2 | Bad input | Show the handle and ask the user to confirm spelling. |
| 3 | Missing dep | Tell user to install yt-dlp and/or python. |
| 4 | Generic fetch failure | Show stderr, suggest retrying in a few minutes. |
| 5 | No browser configured | Run the first-run setup above. |
| 6 | Cookie DB locked | Ask user to **close all windows of their browser** (check tray/background). Then retry. Once it succeeds, tell them they can reopen the browser. |
| 7 | Cookie decrypt failed (Chrome ABE) | Explain ABE and suggest the two reliable paths upfront: "(A) Firefox — log into IG there and reply `firefox`. (B) Install the **Get cookies.txt LOCALLY** extension in your current browser → open instagram.com → Export → save as `~/reel-engine/cookies.txt` → tell me. Which?" If (A), rewrite `scout.conf` to `BROWSER=firefox`. If (B), delete `scout.conf` so the script falls back to `cookies.txt`. |
| 8 | Not logged in / session expired | **Chrome-family configured (chrome/opera/edge/brave):** almost certainly ABE silently blocking `sessionid` — a re-login loop won't fix it. Say: "Chrome-family blocks external reads of the auth cookie (ABE). Fastest path: install the **Get cookies.txt LOCALLY** extension → open instagram.com → Export → save as `~/reel-engine/cookies.txt` → tell me. Alternative: Firefox (reply `firefox` and I'll switch the config)." When `cookies.txt` arrives, delete `scout.conf` so the script uses it. **Firefox configured:** session likely expired — ask the user to log in to IG on Firefox and retry. **cookies.txt mode:** the file has likely expired — ask them to re-export with the same extension. |
| 9 | Rate-limited | Say: "Instagram rate-limited us. I'll pause; try again in 10-30 minutes. The 2-hour cache will protect you if you re-run on the same handle." Stop the batch. |
| 10 | Invalid BROWSER value | Tell user the allowed list, rewrite scout.conf to their corrected choice. |

On codes 4, 6, 7, 8, 9 inside a multi-handle loop: note the failure for that handle and **continue to the next**, unless it's code 9 (rate limit), which should stop the loop so we don't make things worse.

## Known traps (read this before debugging)

These have bitten before. If the symptom matches, apply the fix immediately — don't spiral into deeper debugging.

### 1. User says "my browser is open and logged in, shouldn't that be enough?"

No. Chrome-family browsers (chrome/edge/opera/brave) **lock the cookie database file while running.** gallery-dl cannot read it. The cookies persist on disk across browser shutdowns — closing the browser does **not** log the user out. The only safe sequence is:

1. User logs in to Instagram in the browser (if not already).
2. User **fully closes** the browser — every window, plus system tray / background.
3. Run the scout. It reads cookies straight from disk.
4. User reopens the browser freely — doesn't affect the already-cached session.

If a user insists their browser needs to stay open, offer the `cookies.txt` fallback (export once via a browser extension, save to `~/reel-engine/cookies.txt`).

### 2. Scout reports "No reels found" but user insists the creator has viral recent posts

This used to be a real bug in the parser (stdin collision in a `python - <<HEREDOC` pipeline — fixed in commit `a856bbd`, Apr 2026). If you see this symptom on a version from before that fix, `git pull` and retry. To sanity-check the fetch layer directly:

```bash
python ~/reel-engine/scripts/scout_fetch.py <handle> --limit 5 --cookies-from-browser <browser>
```

That emits raw JSONL. If it shows reels with real `view_count` values but the shell script still says "no reels found", the parser is broken — update the repo.

### 3. Windows: UnicodeEncodeError / cp1252 on emoji in captions

Instagram captions routinely contain emoji (🤝) and curly quotes that the default Windows terminal encoding (cp1252) can't render. The parser block now forces `sys.stdout.reconfigure(encoding="utf-8", errors="replace")` — if you see this crash on a downstream script, apply the same fix.

### 4. Windows: `python3` resolves to the Microsoft Store stub

`command -v python3` returns success for a stub that just prints an install ad and exits. The dispatcher in `scout_reels.sh` already probes candidates with `import sys` before trusting them. If you're writing a new wrapper, use the same probe — don't trust `command -v` alone.

## Daily outlier journal

Every time scout finds 5x+ outliers, they're appended to `~/reel-engine/outliers/YYYY-MM-DD.md` — one file per day, grouped by handle. Running the same handle twice in a day doesn't duplicate (dedup by URL). If the user asks "what did I find yesterday?" or "show me this week's outliers", just `cat` the relevant file(s).

## Caching

The script caches successful scans at `~/reel-engine/.scout_cache/<handle>.json` for 2 hours. If the user re-scouts the same handle within that window, it reads from cache — no network call. This is deliberate rate-limit protection. If the user needs a fresh scan sooner, they can delete the specific cache file; don't do it automatically.

## What the report looks like

After all handles are scanned, print a short **NEXT STEP** footer:

```
NEXT STEP
Pick an outlier and run /reel-grab <url> to pull it into the pipeline.
Then /reel-decode → answer 3 questions → /reel-adapt.
```

## Limitations — be honest

- **Requires login.** Instagram blocks anonymous profile scraping; cookies from a logged-in browser session are required.
- **View counts can be missing.** Reels without a view count are silently skipped (Instagram sometimes withholds them in the grid).
- **Baseline needs at least 3 reels.** Fewer, and you get a simple list.
- **No content summary beyond caption excerpt.** Scout is deliberately cheap. Deep analysis happens in `/reel-decode`.

## Don't overreach

Scout is read-only discovery. Don't download, transcribe, or decode from here. Print the report and stop. The user chooses which outlier enters the pipeline.
