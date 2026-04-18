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

Before the first scout, check whether `~/reel-engine/scout.conf` exists. If **neither** `scout.conf` **nor** `~/reel-engine/cookies.txt` exists, **stop and ask the user once** (if `cookies.txt` is already present, skip the question — the script will use it automatically as a fallback):

> "To scout Instagram, I need to read your browser cookies so Instagram sees us as a logged-in user (Instagram blocks anonymous profile scraping).
>
> Which browser do you have Instagram logged into?
> - chrome
> - firefox
> - edge
> - opera
> - brave
>
> Reply with the name (e.g. `chrome`)."

When they answer:
1. Write `~/reel-engine/scout.conf` with `BROWSER=<their choice>` (lowercase).
2. If they chose Chrome-family (chrome/edge/opera/brave), warn: "Before I run scout, please **close all windows of that browser** (including background — check tray). Chrome-family browsers lock their cookie DB while running. I'll let you know when it's safe to reopen (takes ~10 seconds)."
3. Then proceed with the scout.

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
| 7 | Cookie decrypt failed (Chrome ABE) | Say: "Chrome's app-bound encryption is blocking cookie decryption. Two options: (A) switch to Firefox — do you have Instagram logged in on Firefox? (B) export cookies manually to `~/reel-engine/cookies.txt` using a browser extension. Which do you prefer?" If (A), update `scout.conf` yourself: set `BROWSER=firefox`. If (B), wait for the file. |
| 8 | Not logged in / session expired | Say: "Instagram says we're not logged in on that browser. Please open <browser>, go to instagram.com, and log in. Then come back and tell me to retry." If it keeps failing after login, the user likely has multiple browser profiles — ask: "Which Instagram account is logged in on <browser> — the one you want to scout with? If you have more than one browser profile, you may be logged in on the other one. Tell me the email of the account." Use the email hint to locate the right profile by listing `~/AppData/Local/<browser>/User Data/` on Windows (look at `Profile N/Preferences` → account email); once found, update `scout.conf`: `PROFILE=<profile dir name>`. |
| 9 | Rate-limited | Say: "Instagram rate-limited us. I'll pause; try again in 10-30 minutes. The 2-hour cache will protect you if you re-run on the same handle." Stop the batch. |
| 10 | Invalid BROWSER value | Tell user the allowed list, rewrite scout.conf to their corrected choice. |

On codes 4, 6, 7, 8, 9 inside a multi-handle loop: note the failure for that handle and **continue to the next**, unless it's code 9 (rate limit), which should stop the loop so we don't make things worse.

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
