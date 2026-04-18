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

**Required header — print this first, before any sections:**

```
## Storyboard

**Mode:** spoken | text_overlay
**Frames analyzed:** N (all) | N of M (sampled every Xth)
**Caption (from post):** <full caption from meta.json, or "not available">
```

In text-overlay mode, the caption from the post is not optional — much of the persuasion lives there. Print it in full.

**Required section format — use this exact template for every section. No tables. No prose-only summaries. Every field filled for every section.**

```
### [Section Name] — [Start]–[End]s

- **Visual:** <environment, people, UI, graphics, text overlays on screen>
- **Spoken (VO):** "<direct quote from SRT for this timestamp range>"
  (In text_overlay mode, replace with **On-screen text:** "<text read from frames>")
- **Caption style:** <color, weight, font style, position — e.g. "yellow serif italic, word-by-word, center">
- **Persuasion mechanic:** <named mechanic — e.g. "output-as-proof", "cognitive dissonance hook", "pattern interrupt">
```

Sections follow the reel's actual narrative arc (Hook / Problem / Solution / Demo / Brand / CTA — or whatever this specific video uses). Don't invent sections; let the frames tell you where the beats are.

**Example of a correctly filled section (spoken mode):**

```
### Hook — 0–3s

- **Visual:** Pixel-art "CLAUDE CODE" logo fills the frame, hard cut to a photorealistic render of a floating soda can against a yellow background.
- **Spoken (VO):** "Claude Code is now a full-blown motion design studio."
- **Caption style:** White bold uppercase, center-screen, word-by-word reveal synced to VO.
- **Persuasion mechanic:** Cognitive-dissonance hook — dev-tool logo + studio render in the same second forces the viewer to stay and resolve the gap.
```

Before moving to step 4, verify every section has **all four bullets filled**. If any bullet would be empty or generic, go back to the frames/SRT and fill it.

### 4. Write "Why This Reel Works"
6–8 specific, named mechanics. Dissect the actual techniques — not generic praise:
- Hook mechanic (what visual device + what spoken claim + what emotion)
- Caption system (how different styles serve different narrative purposes)
- Proof structure (how the video earns trust before asking for anything)
- Pacing and editing rhythm
- Pattern interrupts, reframes, emotional beats
- CTA structure (what's offered and why it converts)

### 5. Save the storyboard NOW (before asking any questions)

Save the full storyboard + "Why This Reel Works" analysis to:

```
~/reel-engine/Reels/Videos/{BaseName} - storyboard.md
```

**This must happen before Q1.** Conversations often end on Q1 if the user walks away. If the file isn't written first, all the analysis is lost and `/reel-adapt` has nothing to read. Confirm the file was written and print the exact path.

### 6. Pre-output checklist — verify before printing

Before emitting the storyboard + analysis to the user, confirm each item:

- [ ] Header prints Mode, Frames analyzed (count + sampling method), and Caption
- [ ] Every section has all 4 bullets filled (Visual / Spoken or On-screen text / Caption style / Persuasion mechanic) — no empty bullets, no generic fillers
- [ ] "Why This Reel Works" has 6–8 named mechanics (not generic praise)
- [ ] Storyboard file was saved to `~/reel-engine/Reels/Videos/{BaseName} - storyboard.md`

If any box is unchecked, fix it before responding. The checklist itself doesn't appear in the output — it's for you.

### 7. Ask 3 questions — one at a time

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

1. **STORYBOARD** — header (Mode / Frames / Caption) + every section in the required template
2. **WHY THIS REEL WORKS** — 6–8 named mechanics
3. **(save file + run checklist silently — do NOT skip)**
4. **"Saved to: `<path>`"** — confirm the file exists
5. **QUESTIONS** — Q1 only. Wait. Then Q2. Wait. Then Q3.

Once all 3 are answered:
> "Run `/reel-adapt` to generate your adapted script and production storyboard."
