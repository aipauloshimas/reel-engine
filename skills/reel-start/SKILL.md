---
name: reel-start
description: Orientation menu for reel-engine. Use when the user runs /reel-start, asks "what can I do", "where do I start", "what are the commands", or seems unsure which skill to run first.
---

# /reel-start: Orientation

Print this menu exactly. Don't paraphrase; the formatting is part of the experience.

```
reel-engine: decode any reel, adapt it for your product.

FIRST TIME:
  /reel-doctor    One-shot system check + repair (Python, ffmpeg, whisper, yt-dlp, cookies).
  /voice-setup    5-minute interview to capture how you sound on camera.

FIND REELS TO ADAPT:
  /reel-scout     Scans a creator (or a list) for viral outliers in the last 30 days.
                  Usage: /reel-scout @handle   or   /reel-scout creators.txt

EVERY REEL:
  /reel-grab      Paste an Instagram URL. Downloads + transcribes + extracts frames.
  /reel-decode    Analyzes the reel. Produces a storyboard + 3 questions.
  /reel-adapt     Takes your answers. Writes a full adapted script + production storyboard.
  /reel-broll     OPTIONAL: after /reel-adapt, layer b-roll cutaways from your library
                  onto the script (personal-only skill, depends on _shared/broll/).

WORKFLOW:
  /reel-scout  →  pick an outlier URL  →  /reel-grab  →  /reel-decode  →  /reel-adapt  →  ready to shoot.
  Add /reel-broll between /reel-adapt and shooting if you want b-rolls layered in.

If a skill complains about a missing tool, run /reel-doctor.

Outputs are saved in the folder you run the session from.
(Older reels live in ~/reel-engine/Reels/Videos/)
```

Then ask:
> "Where do you want to start? If it's your first time, run `/reel-doctor` then `/voice-setup`. Otherwise paste a reel URL."

Do not run any other skill automatically. Let the user pick.
