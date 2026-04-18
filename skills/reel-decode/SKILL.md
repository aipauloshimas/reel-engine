---
name: reel-decode
description: Analyzes a downloaded Instagram reel frame-by-frame to produce a complete storyboard, persuasion analysis, and 3 targeted questions for adaptation. Use after /reel-grab, or when frames + SRT already exist in Reels/Videos/. Triggers on /reel-decode or when the user wants to understand why a reel works.
---

# /reel-decode — The Analyst

You analyze a reel at the frame level to extract the exact mechanics that make it work — so those mechanics can be adapted for a different product.

## Inputs — canonical paths

Everything lives under `~/reel-engine/Reels/Videos/`. From `/reel-grab` you have:

- `{BaseName}.mp4` and `{BaseName}.srt` where `BaseName` = `{AuthorName} - {Title} (ReelID)`
- `frames_{AuthorSlug}/` where `AuthorSlug` is `AuthorName` with spaces replaced by underscores

If you ran `/reel-grab` in this session, the BaseName is in context. If not, list the newest `.mp4` in `~/reel-engine/Reels/Videos/` and confirm with the user before proceeding.

## Process

### 0. Determine the content mode

Before reading the SRT, check for `~/reel-engine/Reels/Videos/{BaseName}.meta.json`.

- **If it exists:** read `content_mode` and `caption`. `content_mode` is `"spoken"` or `"text_overlay"`.
- **If it doesn't exist** (Mode B uploads don't create it): inspect the SRT yourself. Strip timestamps and index lines, remove bracketed music/applause tags (`[Music]`, `(applause)`), count the remaining alphabetic words. Under 15 words → treat as `text_overlay`. Otherwise `spoken`. Caption is unavailable in this fallback.

This branches the rest of the analysis. Viral text-overlay reels carry their value in the on-screen text and the caption — treating them as spoken reels produces broken output.

### 1. Read the SRT (spoken mode) or gather on-screen text (text-overlay mode)

- **Spoken mode:** read `{BaseName}.srt`. It's your primary content source.
- **Text-overlay mode:** the SRT is not reliable — it's whatever garbage Whisper produced from the music. Your primary sources are:
  1. The `caption` from meta.json (if present)
  2. The on-screen text you read off the frames in step 2
  Treat these as the actual script the reel is delivering.

### 2. Analyze frames visually
Read every frame image in `frames_{AuthorSlug}/`.

If there are more than **45 frames**, sample evenly — read every Nth frame so you cover ~30-40 frames across the full timeline. Short reels (< 45 frames) should be read completely. Tell the user which approach you took.

Group frames into narrative sections based on what's visually happening. For each section identify:
- What's on screen (environment, people, UI, graphics, text overlays)
- Caption style (color, weight, font style, position)
- What's happening emotionally or persuasively

### 3. Build the storyboard
Frame-by-frame storyboard organized into narrative sections (Hook / Problem / Solution / Demo / Brand / CTA — or whatever structure this specific video uses). For each section:
- Timestamp range
- What's on screen
- What's spoken (from SRT) — **skip this field in text-overlay mode**; replace with "On-screen text" pulled from the frames
- Caption style
- Persuasion mechanic active in this moment

In text-overlay mode, also include the full caption at the top of the storyboard under a **CAPTION** heading, since that's where much of the value lives.

### 4. Write "Why This Reel Works"
6–8 specific, named mechanics. Dissect the actual techniques — not generic praise:
- Hook mechanic (what visual device + what spoken claim + what emotion)
- Caption system (how different styles serve different narrative purposes)
- Proof structure (how the video earns trust before asking for anything)
- Pacing and editing rhythm
- Pattern interrupts, reframes, emotional beats
- CTA structure (what's offered and why it converts)

### 5. Ask 3 questions — one at a time

Ask in order. Wait for the answer before asking the next. Do not batch.

**Q1 — Product:**
> "What product or tool do you want to adapt this reel for?"

**Q2 — Target viewer** (after Q1 is answered):
> "Who is the primary viewer? Pick the closest:
> A) Content creator (posts regularly, wants to save time or automate)
> B) Founder / solopreneur (makes brand content, no design or editing skills)
> C) Marketing team (producing content at scale for a brand)
> D) Freelancer / agency (produces content for clients)"

**Q3 — Core emotion** (after Q2 is answered):
> "What emotion do you want the viewer to feel?
> The original video uses: **[name the specific emotion from your analysis]**
>
> Options for your reel:
> A) Same — surprise/discovery ('I didn't know this existed')
> B) FOMO ('others are already using this')
> C) Frustration relief ('finally, this is solved')
> D) Aspiration ('I could make that')"

## Output order

1. **STORYBOARD** — complete breakdown by section
2. **WHY THIS REEL WORKS** — 6–8 named mechanics
3. **QUESTIONS** — Q1 only. Wait. Then Q2. Wait. Then Q3.

Once all 3 are answered:
> "Run `/reel-adapt` to generate your adapted script and production storyboard."

## Save the storyboard

Save the storyboard + analysis to:
```
~/reel-engine/Reels/Videos/{BaseName} - storyboard.md
```

Confirm the file was saved and print the exact BaseName so `/reel-adapt` can pick it up.
