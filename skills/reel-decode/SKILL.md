---
name: reel-decode
description: Use after /reel-grab, or when a reel's mp4 + SRT + frames already exist on disk, and the user wants the reel analyzed, decoded, or explained (why it works) before adapting it. Triggers on /reel-decode.
---

# /reel-decode: The Analyst

You analyze a reel at the frame level to extract the exact mechanics that make it work, so those mechanics can be adapted for a different product.

## Inputs

Reels live in the **session folder** (the current working directory of this conversation; `/reel-grab` saves everything there). Older reels live in the legacy folder `~/reel-engine/Reels/Videos/`. From `/reel-grab` you have:

- `{BaseName}.mp4` and `{BaseName}.srt` where `BaseName` = `{AuthorName} - {Title} (ReelID)`
- `frames_{AuthorSlug}_{ReelID}/` where `AuthorSlug` is `AuthorName` (the text before the FIRST ` - `) with spaces replaced by underscores, and `ReelID` is the content of the final `(...)` in BaseName

If you ran `/reel-grab` in this session, the BaseName is in context. If not, list the newest `.mp4` files (session folder first, then the legacy folder), note which ones already have a ` - storyboard.md`, and confirm with the user before proceeding.

### Frames folder: verify before trusting

1. Prefer `frames_{AuthorSlug}_{ReelID}/`.
2. If only a legacy `frames_{AuthorSlug}/` (no ReelID suffix) exists, do NOT trust it blindly: it may contain frames from ANOTHER reel by the same author. Check the frame count against the video duration (expect roughly 1 frame per second):
   ```bash
   ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "<the .mp4>"
   ```
   If the count differs from the duration by more than 2, or the folder is missing or empty, re-extract using the frame-extraction snippet from `/reel-grab` (it also cleans stale frames).
3. Extraction takes seconds. When in doubt, re-extract.

## Process

### 0. Determine the content mode

Before reading the SRT, check for `{BaseName}.meta.json` next to the mp4.

- **If it exists:** read `content_mode` and `caption`. `content_mode` is `"spoken"` or `"text_overlay"`.
- **If it doesn't exist** (Mode B uploads don't create it): inspect the SRT yourself. Strip timestamps and index lines, remove bracketed music/applause tags (`[Music]`, `(applause)`), count the remaining alphabetic words. Under 15 words = treat as `text_overlay`. Otherwise `spoken`. Caption is unavailable in this fallback. (Keep this 15-word threshold in sync with the detection in `~/reel-engine/scripts/transcribe_reel.sh`, which uses the same value.)

This branches the rest of the analysis. Viral text-overlay reels carry their value in the on-screen text and the caption; treating them as spoken reels produces broken output.

### 1. Read the SRT (spoken mode) or gather on-screen text (text-overlay mode)

- **Spoken mode:** read `{BaseName}.srt`. It's your primary content source.
- **Text-overlay mode:** the SRT is not reliable; it's whatever garbage Whisper produced from the music. Your primary sources are:
  1. The `caption` from meta.json (if present)
  2. The on-screen text you read off the frames in step 2
  Treat these as the actual script the reel is delivering.

### 2. Analyze frames visually

Read every frame image in the frames folder (verified in Inputs above).

If there are more than **45 frames**, sample evenly: read every Nth frame so you cover ~30-40 frames across the full timeline. Short reels (under 45 frames) should be read completely. Tell the user which approach you took.

Group frames into narrative sections based on what's visually happening. For each section identify:
- What's on screen (environment, people, UI, graphics, text overlays)
- Caption style (color, weight, font style, position)
- What's happening emotionally or persuasively

### 3. Build the storyboard

**Required header. Print this first, before any sections:**

```
## Storyboard

**Mode:** spoken | text_overlay
**Frames analyzed:** N (all) | N of M (describe the sampling pattern, e.g. "every 2nd" or "2 of every 3")
**Caption (from post):** <full caption from meta.json, or "not available">
```

In text-overlay mode, the caption from the post is not optional; much of the persuasion lives there. Print it in full.

**Required section format. Use this exact template for every section. No tables. No prose-only summaries. Every field filled for every section.**

```
### [Section Name], [Start]-[End]s   (timestamps in whole seconds)

- **Visual:** <environment, people, UI, graphics, text overlays on screen>
- **Spoken (VO):** "<direct quote from SRT for this timestamp range>"
  (In text_overlay mode, replace with **On-screen text:** "<text read from frames>")
- **Caption style:** <color, weight, font style, position, e.g. "yellow serif italic, word-by-word, center">
- **Persuasion mechanic:** <named mechanic, e.g. "output-as-proof", "cognitive dissonance hook", "pattern interrupt">
```

Sections follow the reel's actual narrative arc (Hook / Problem / Solution / Demo / Brand / CTA, or whatever this specific video uses). Don't invent sections; let the frames tell you where the beats are.

**Example of a correctly filled section (spoken mode):**

```
### Hook, 0-3s

- **Visual:** Pixel-art "CLAUDE CODE" logo fills the frame, hard cut to a photorealistic render of a floating soda can against a yellow background.
- **Spoken (VO):** "Claude Code is now a full-blown motion design studio."
- **Caption style:** White bold uppercase, center-screen, word-by-word reveal synced to VO.
- **Persuasion mechanic:** Cognitive-dissonance hook: dev-tool logo + studio render in the same second forces the viewer to stay and resolve the gap.
```

Before moving to step 4, verify every section has **all four bullets filled**. If any bullet would be empty or generic, go back to the frames/SRT and fill it.

### 4. Write "Why This Reel Works"

6-8 specific, named mechanics. Dissect the actual techniques, not generic praise:
- Hook mechanic (what visual device + what spoken claim + what emotion)
- Caption system (how different styles serve different narrative purposes)
- Proof structure (how the video earns trust before asking for anything)
- Pacing and editing rhythm
- Pattern interrupts, reframes, emotional beats
- CTA structure (what's offered and why it converts)

### 5. Pre-output checklist: verify before saving or printing

Confirm each item:

- [ ] Header prints Mode, Frames analyzed (count + sampling method), and Caption
- [ ] Every section has all 4 bullets filled (Visual / Spoken or On-screen text / Caption style / Persuasion mechanic), no empty bullets, no generic fillers
- [ ] "Why This Reel Works" has 6-8 named mechanics (not generic praise)

If any box is unchecked, fix it before continuing. The checklist itself doesn't appear in the output; it's for you.

### 6. Save the storyboard NOW (before printing, before any questions)

Save the full storyboard + "Why This Reel Works" analysis next to the mp4:

```
{same folder as the mp4}/{BaseName} - storyboard.md
```

**This must happen before Q1.** Conversations often end on Q1 if the user walks away. If the file isn't written first, all the analysis is lost and `/reel-adapt` has nothing to read. Confirm the file was written and print the exact path.

If a storyboard file already exists for this reel (you're re-running the analysis), delete it first and write fresh. Never merge with stale content, and don't read the old one as a reference; it may describe frames that are no longer trusted.

### 7. Ask 3 questions, one at a time

Ask in order. Wait for the answer before asking the next. Do not batch.

**Q1, Product (open question, plain text):**
> "What product or tool do you want to adapt this reel for?"

**Q2, Target viewer** (after Q1 is answered). Use the **AskUserQuestion tool** with these 4 options (the tool adds "Other" automatically):
- A) Content creator (posts regularly, wants to save time or automate)
- B) Founder / solopreneur (makes brand content, no design or editing skills)
- C) Marketing team (producing content at scale for a brand)
- D) Freelancer / agency (produces content for clients)

**Q3, Core emotion** (after Q2 is answered). Use the **AskUserQuestion tool**. In the question text, name the specific emotion the original uses (from your analysis). Options:
- A) Same as the original: surprise/discovery ("I didn't know this existed")
- B) FOMO ("others are already using this")
- C) Frustration relief ("finally, this is solved")
- D) Aspiration ("I could make that")

### 8. Persist the answers (do not skip)

As soon as Q3 is answered, append to the storyboard file:

```
## Adaptation answers

- **Product:** <answer>
- **Target viewer:** <answer>
- **Core emotion:** <answer>
```

Why: conversations die between `/reel-decode` and `/reel-adapt`. The storyboard is saved before Q1 for exactly that reason; the answers deserve the same protection. `/reel-adapt` reads them from this section when the chat context is gone.

## Output order (canonical)

1. Compose the full storyboard + "Why This Reel Works" internally.
2. Run the pre-output checklist (step 5). Fix anything unchecked.
3. Save the file (step 6).
4. Print: **STORYBOARD**, then **WHY THIS REEL WORKS**, then **"Saved to: `<path>`"**.
5. **QUESTIONS**: Q1 only. Wait. Then Q2 (AskUserQuestion). Wait. Then Q3 (AskUserQuestion).
6. Append the answers to the storyboard file (step 8).

Once all 3 are answered and persisted:
> "Run `/reel-adapt` to generate your adapted script and production storyboard."
