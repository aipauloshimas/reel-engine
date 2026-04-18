---
name: voice-setup
description: Interviews the user to discover their authentic on-camera voice and writing style, then generates and saves a VOICE.md file. Use when the user runs /voice-setup, says they want to define their voice, or before running /reel-adapt for the first time. This must run before any script is written.
---

# /voice-setup — The Voice Interview

You help the creator find and articulate their on-camera voice so every script sounds like them — not like a template.

This is a 5-minute interview. One question at a time. No rushing. The user can always say "skip" to any question and you'll come back to it at the end.

## Files

- **Template** (never edit): `~/reel-engine/VOICE.template.md`
- **User's profile** (what you write): `~/reel-engine/VOICE.md`

## Setup — detect state

Read the first 3 lines of `~/reel-engine/VOICE.md` if it exists.

- **File missing** → first run. Copy the template:
  ```bash
  cp ~/reel-engine/VOICE.template.md ~/reel-engine/VOICE.md
  ```
  Proceed with interview.
- **Any of the first 3 lines contains `STATUS: template`** → user hasn't filled it in yet. Proceed with interview.
- **Any of the first 3 lines contains `STATUS: configured`** → already set up. Ask:
  > "You already have a voice profile. Want to update it, or start fresh?"
  - "update" → read the current VOICE.md so you can reference existing answers.
  - "start fresh" → overwrite with the template and proceed.

If neither marker is present (file edited manually), treat as template and proceed.

## The interview — one question at a time

Ask each question, wait, then move on. Do not batch. After each answer, reflect it back in one line so the user knows you understood.

If the user says "skip" on any question, write `(skipped — fill in later)` for that section and move on. Don't push.

### Q1 — Niche (→ `## My niche`)
> "What do you make content about? Be as specific as possible — not just the topic, but the angle.
>
> For example:
> - 'AI tools, but specifically for creators who post every day'
> - 'Personal finance, but for people who hate spreadsheets'
> - 'No-code automation, specifically for agency owners'
>
> What's yours?"

### Q2 — Audience (→ `## My audience`)
> "Who watches you — and what's their main frustration?
>
> Examples:
> - 'Founders who want to post consistently but have no time to edit'
> - 'Creators who know they should be making videos but keep putting it off'
> - 'Small business owners who feel like tech tools are built for people smarter than them'
>
> Who's your person?"

### Q3 — Your tone (→ `## My tone`)
> "How would a friend describe the way you talk on camera?
>
> Examples:
> - 'Direct, no-fluff — gets to the point in 5 seconds'
> - 'Energetic teacher who makes hard things feel easy'
> - 'Calm and confident, like someone who already figured it out'
>
> What fits you?"

### Q4 — Natural phrases (→ `## Phrases I use naturally`)
> "What words or expressions do you actually say — not what sounds good, what sounds like you?
>
> Think about how you explain something to a friend. What phrases come out?
>
> Examples: 'straight up', 'here's the thing', 'look', 'in practice', 'real talk'"

### Q5 — Phrases to avoid (→ `## Phrases I avoid`)
> "What words or phrases feel fake or corporate to you — things you'd never say on camera?
>
> Examples: 'game-changer', 'revolutionary', 'mind-blowing', 'in today's video', 'don't forget to like and subscribe'.
>
> Give me a few."

### Q6 — Tone reference (→ `## Creators whose style I respect`)
> "Think of 2–3 creators you actually enjoy watching — not who you want to be, but who feels natural when you watch them. Saying 'I'm not sure' is fine; you can also name someone outside your niche.
>
> Name them, and say one word about what you like about each."

After the answer, make a brief observation about what those creators have in common tonally (e.g. "All three are confident without being loud"). Ask: "Does that feel right?" — if skipped, just move on.

### Q7 — What you hate sounding like (→ `## What I never want to sound like`)
> "What style of creator do you never want to sound like? Be specific — this becomes a hard 'avoid' list.
>
> Examples:
> - 'The hype guy — everything is INSANE and MIND-BLOWING'
> - 'The corporate presenter — sounds like a webinar'
> - 'The over-humble one — always qualifying, never confident'"

### Q8 — One-line self-description (→ `## One-line self-description`)
> "If a viewer had to describe you to a friend in one sentence — not what you make, but how you come across — what would you want them to say?
>
> Example: 'He's the guy who explains complex stuff without making you feel dumb.'"

## Revisit skipped questions

After Q8, list any questions the user skipped and ask one more time:
> "You skipped [Q3 — tone] and [Q5 — phrases to avoid]. Want to fill those in now, or leave them for later?"

If they still skip, mark those sections `(skipped — fill in later)` in the final file.

## After the interview — write VOICE.md

Synthesize every answer into a completed VOICE.md. **Preserve the section headings exactly** (so `/reel-adapt` can parse them):

- `## My niche`
- `## My audience`
- `## My tone`
- `## Phrases I use naturally`
- `## Phrases I avoid`
- `## Creators whose style I respect`
- `## What I never want to sound like`
- `## One-line self-description`

**Critical first line:** the very first line of the file must be exactly:
```
<!-- STATUS: configured -->
```

No blank line before it, no BOM, no spaces. `/reel-adapt` relies on this marker.

Be concrete. Avoid vague adjectives like "authentic" or "relatable." Write it as a usable reference, not a transcript of the interview.

Save to `~/reel-engine/VOICE.md` (overwrite).

Then say:
> "Your voice profile is saved. Every script from `/reel-adapt` will use it. Update any time by running `/voice-setup` again.
>
> Ready to analyze a reel? Drop an Instagram URL and run `/reel-grab`."
