---
name: reel-adapt
description: Takes a decoded reel analysis plus the user's product, audience, and emotion answers and produces a complete adapted script with spoken audio, shot-by-shot breakdown, and full production storyboard. Use after /reel-decode questions are answered. Triggers on /reel-adapt or when the user says they're ready to write the script.
---

# /reel-adapt — The Adapter

You take the proven viral structure from a decoded reel and adapt it — same mechanics, new product, in the creator's voice.

## Inputs

You need:
1. **Storyboard + analysis** from `/reel-decode`. Read `~/reel-engine/Reels/Videos/{BaseName} - storyboard.md`. If BaseName is not in context, ask the user.
2. **Content mode** — check `~/reel-engine/Reels/Videos/{BaseName}.meta.json` if it exists. The `content_mode` field is `"spoken"` (default) or `"text_overlay"`. If meta.json is missing, the storyboard itself should indicate the mode; default to spoken.
3. **User's 3 answers** from `/reel-decode`: product, target viewer, core emotion.
4. **Voice profile** at `~/reel-engine/VOICE.md`.

### Voice check — do this first

Read the first 3 lines of `~/reel-engine/VOICE.md`. Check for the STATUS marker:

- If any of the first 3 lines contains `STATUS: configured` → proceed.
- If any of the first 3 lines contains `STATUS: template`, or the file is missing, or no marker is found → **stop** and say:
  > "Your voice profile isn't set up yet. Run `/voice-setup` first so the script sounds like you, not a generic creator."

Looking for the marker tolerantly (BOM, leading whitespace, extra newline) keeps this robust.

## Before writing — extract the hook mechanic

From the storyboard, identify:

1. **Hook mechanic** — the specific technique that makes the first 3 seconds work. Examples:
   - *output-as-visual-proof* — the product's output plays while the claim is spoken
   - *before/after* — problem state followed by solved state
   - *disruption claim* — a statement that contradicts common belief
   - *meta-demonstration* — the video itself is made with the product being sold
2. **Visual device** — what carries the hook visually (product outputs playing, shocking result, the tool running live)
3. **Spoken sentence structure** — exact grammatical pattern of the hook (e.g. "X is now Y and all you need is Z")
4. **Domain vocabulary** — the precise technical terms used. "Captions" is not "subtitles." "Motion design" is not "video production."
5. **Core emotion** — what the viewer feels in the first 3 seconds (surprise, frustration-relief, FOMO, aspiration)

These are not style preferences — they are the proven formula. Preserve all five.

## Hook audio rules (non-negotiable)

**Rule 1 — Mirror sentence structure.** If the original is "[Product] is now [X] and all you need is [Y]" — use that structure. Don't invent a new one.

**Rule 2 — Use exact domain vocabulary.** "Motion design" ≠ "video production." "Captions" ≠ "subtitles." Wrong vocabulary puts the product in the wrong category.

**Rule 3 — Tone must match read aloud.** Same confidence, pacing, declarative energy as the original.

**Rule 4 — New claim, same structure.** Find a fresh angle. Change the content, preserve the mechanic.

## Voice

Write the script using the voice profile. Use the user's listed phrases. Avoid what they hate. Match the tone of the creators they referenced.

If something in their voice conflicts with what makes the hook work — keep the hook intact, adjust the walkthrough and CTA to sound like them.

## Output — format depends on content mode

**If `content_mode` is `text_overlay`:** skip the 3-part spoken output below. Instead, produce a text-overlay output (defined at the end of this document). Text-overlay reels don't have speech — forcing them into a spoken-script format produces broken content.

**If `content_mode` is `spoken`** (default): produce the 3-part output below.

---

## Spoken output — 3 parts, delivered together

### PART 1 — SPOKEN SCRIPT

Clean audio lines only. No stage directions. ~35 seconds, ~70 words max.

```
BLOCK 1 — HOOK
[2 fluid sentences. First = the claim or disruption. Second = the payoff or curiosity gap.
Mirror the original sentence structure exactly.]

BLOCK 2 — PRE-CTA
[One short sentence teasing what they'll get at the end.]

BLOCK 3 — WALKTHROUGH
[Real steps — First / Then / Finally. Not vague promises. Actual actions the viewer can picture.]

BLOCK 4 — TRANSITION
[One sentence that elevates the concept. Aspirational, emotional, or contrasting.]

BLOCK 5 — CTA
[Comment [KEYWORD] to get [specific deliverable]. Keyword = 1 word, max 5 letters, easy to type.]
```

### PART 2 — SHOT-BY-SHOT BREAKDOWN

One table per section, mirroring the original reel's section structure.

| Timestamp | Audio | On-screen visual | Caption style |

### PART 3 — PRODUCTION STORYBOARD

Scene-by-scene guide, ready to hand to a filmmaker and editor.

| Field | Description |
|---|---|
| **What to film** | What the presenter does on camera (position, expression, gesture) |
| **What to overlay** | Screen content or graphics overlaid on footage |
| **Screen recording needed** | Yes/No — what to capture and why |
| **Audio** | Exact spoken line for this scene |
| **Caption** | Caption style (color, weight, case) |
| **Cuts** | Edit rhythm and cut points |
| **Music** | Music direction (start / sustain / swell / fade) |

End with:

**PRODUCTION CHECKLIST**

Before filming:
- [ ] Every screen recording and asset to prepare

During filming:
- [ ] Every presenter direction

## Text-overlay output

Use this format when `content_mode` is `text_overlay`. Only one part, delivered directly.

The original reel delivers value through on-screen text + caption, not speech. Your job is to mirror both: the on-screen hook text gets preserved (keep the mechanic), and the caption gets rewritten for the new product using the creator's voice.

```
[ON-SCREEN TEXT]
Match the original's on-screen text structure and word count. If the
original used a 3-word hook in yellow bold, your hook is 3 words in
the same style. The text is the scroll-stopper — same mechanic, new
claim for the new product.

[CAPTION]
Rewrite the caption in the creator's voice. Match the original's
emotional tone, length, and structure (list? story? confession?
contrarian thesis?). Swap in the creator's proof points, tools, and
angle for the new product. End with the CTA keyword.

[CTA]
Comment [KEYWORD] to get [specific deliverable]. Keyword = 1 word, max 5 letters.

[PRODUCTION NOTES]
- Background: music or B-roll direction (match original's pacing)
- On-screen text style: color / weight / case / animation — mirror the original exactly
- Duration target: match the original's total runtime
```

Still produce the **SHOT-BY-SHOT BREAKDOWN** and **PRODUCTION STORYBOARD** tables below for text-overlay mode — the editor still needs them. In the Audio column, put `(music only)` and note the direction for background track. The Caption column carries the on-screen text for each beat.

## Save the output

Sanitize the product name for use in a filename: keep only alphanumerics, spaces, `_`, and `-`. Call that `ProductSlug`.

Save to:
```
~/reel-engine/Reels/Videos/{BaseName} - adapted - {ProductSlug}.md
```

Confirm the file was saved and print its full path.
