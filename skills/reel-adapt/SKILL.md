---
name: reel-adapt
description: Use after /reel-decode, when a reel storyboard exists and the user is ready to turn it into a script for their own product. Triggers on /reel-adapt or when the user says they're ready to write the script.
---

# /reel-adapt: The Adapter

You take the proven viral structure from a decoded reel and adapt it: same mechanics, new product, in the creator's voice.

## Inputs

You need:

1. **Storyboard + analysis** from `/reel-decode`: `{BaseName} - storyboard.md`, in the **session folder** (the current working directory) or in the legacy `~/reel-engine/Reels/Videos/`. If BaseName is not in context, list the newest `* - storyboard.md` files (session folder first, then legacy) and confirm with the user before proceeding.
2. **Content mode**: check `{BaseName}.meta.json` next to the storyboard if it exists. The `content_mode` field is `"spoken"` (default) or `"text_overlay"`. If meta.json is missing, the storyboard header indicates the mode; default to spoken.
3. **The 3 adaptation answers** (product, target viewer, core emotion). Read them from the `## Adaptation answers` section at the end of the storyboard file. If that section is missing (older storyboards) and the answers aren't in the chat context, re-ask the 3 questions from `/reel-decode` before writing anything: product as an open question, viewer and emotion via the AskUserQuestion tool.
4. **Voice profile** at `~/reel-engine/VOICE.md`.

### Voice check: do this first

Read the first 3 lines of `~/reel-engine/VOICE.md`. Check for the STATUS marker:

- If any of the first 3 lines contains `STATUS: configured`, proceed.
- If any of the first 3 lines contains `STATUS: template`, or the file is missing, or no marker is found, **stop** and say:
  > "Your voice profile isn't set up yet. Run `/voice-setup` first so the script sounds like you, not a generic creator."

Look for the marker tolerantly (BOM, leading whitespace, extra newline all fine).

## Language

The script comes out in the language of the CREATOR's channel, not the original reel's. Resolve it in this order:

1. An explicit request from the user in this session
2. The `## Channel language` section of VOICE.md (newer profiles have it)
3. If still ambiguous (e.g. the creator publishes in more than one language), ask once before writing

Never silently inherit the original reel's language just because the transcript is in it.

## Duration target

Match the original reel's runtime: take the end timestamp of the last storyboard section (or the last SRT timestamp if available) and target that length at roughly 2 words per second of speech. When the original runtime is unknown, default to ~35 seconds / ~70 words. Never stretch a tight hook to fill time; trim the walkthrough instead of padding.

## Before writing: extract the hook mechanic

From the storyboard, identify:

1. **Hook mechanic**: the specific technique that makes the first 3 seconds work. Examples:
   - *output-as-visual-proof*: the product's output plays while the claim is spoken
   - *before/after*: problem state followed by solved state
   - *disruption claim*: a statement that contradicts common belief
   - *meta-demonstration*: the video itself is made with the product being sold
2. **Visual device**: what carries the hook visually (product outputs playing, shocking result, the tool running live)
3. **Spoken sentence structure**: exact grammatical pattern of the hook (e.g. "X is now Y and all you need is Z")
4. **Domain vocabulary**: the precise technical terms used. "Captions" is not "subtitles." "Motion design" is not "video production."
5. **Core emotion**: what the viewer feels in the first 3 seconds (surprise, frustration-relief, FOMO, aspiration)

These are not style preferences; they are the proven formula. Preserve all five.

## Hook audio rules (non-negotiable)

**Rule 1: Mirror sentence structure.** If the original is "[Product] is now [X] and all you need is [Y]", use that structure. Don't invent a new one.

**Rule 2: Use exact domain vocabulary.** "Motion design" is not "video production." "Captions" is not "subtitles." Wrong vocabulary puts the product in the wrong category.

**Rule 3: Tone must match read aloud.** Same confidence, pacing, declarative energy as the original.

**Rule 4: New claim, same structure.** Find a fresh angle. Change the content, preserve the mechanic.

## Voice

Write the script using the voice profile. Use the user's listed phrases. Avoid what they hate. Match the tone of the creators they referenced.

If something in their voice conflicts with what makes the hook work: keep the hook intact, adjust the walkthrough and CTA to sound like them.

## Output: format depends on content mode

**If `content_mode` is `text_overlay`:** skip the 3-part spoken output below. Instead, produce a text-overlay output (defined at the end of this document). Text-overlay reels don't have speech; forcing them into a spoken-script format produces broken content.

**If `content_mode` is `spoken`** (default): produce the 3-part output below.

---

## Spoken output: 3 parts, delivered together

### PART 1: SPOKEN SCRIPT

Clean audio lines only. No stage directions. Length per the Duration target section above.

```
BLOCK 1 - HOOK
[2 fluid sentences. First = the claim or disruption. Second = the payoff or curiosity gap.
Mirror the original sentence structure exactly.]

BLOCK 2 - PRE-CTA
[One short sentence teasing what they'll get at the end.]

BLOCK 3 - WALKTHROUGH
[Real steps: First / Then / Finally. Not vague promises. Actual actions the viewer can picture.]

BLOCK 4 - TRANSITION
[One sentence that elevates the concept. Aspirational, emotional, or contrasting.]

BLOCK 5 - CTA
[Comment [KEYWORD] to get [specific deliverable]. Keyword = 1 word, max 5 letters, easy to type.]
```

### PART 2: SHOT-BY-SHOT BREAKDOWN

One table per section, mirroring the original reel's section structure.

| Timestamp | Audio | On-screen visual | Caption style |

### PART 3: PRODUCTION STORYBOARD

Scene-by-scene guide, ready to hand to a filmmaker and editor.

| Field | Description |
|---|---|
| **What to film** | What the presenter does on camera (position, expression, gesture) |
| **What to overlay** | Screen content or graphics overlaid on footage |
| **Screen recording needed** | Yes/No, what to capture and why |
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
the same style. The text is the scroll-stopper: same mechanic, new
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
- On-screen text style: color / weight / case / animation, mirror the original exactly
- Duration target: match the original's total runtime
```

Still produce the **SHOT-BY-SHOT BREAKDOWN** and **PRODUCTION STORYBOARD** tables (defined above in the spoken output) for text-overlay mode; the editor still needs them. In the Audio column, put `(music only)` and note the direction for the background track. The Caption column carries the on-screen text for each beat.

## Save the output

Sanitize the product name for use in a filename: keep only alphanumerics, spaces, `_`, and `-`. Call that `ProductSlug`.

Save next to the storyboard file (same folder):
```
{same folder as the storyboard}/{BaseName} - adapted - {ProductSlug}.md
```

Confirm the file was saved and print its full path.

## Output the full storyboard inline

After saving, you MUST emit the entire storyboard in your response. Do not summarize, do not ask if the user wants to see it, do not stop at the file path. Print all three parts inline, in this order:

1. **PART 1: SPOKEN SCRIPT** (complete, in a code block)
2. **PART 2: SHOT-BY-SHOT BREAKDOWN** (complete table)
3. **PART 3: PRODUCTION STORYBOARD** (complete scene-by-scene table + production checklist)

Only after all three parts are emitted, add the hand-off line:

> "If you want b-roll cutaways layered in, run `/reel-broll` next; it'll read this script, surface your library, and suggest cutaways per shot. Otherwise the script is ready to film."
