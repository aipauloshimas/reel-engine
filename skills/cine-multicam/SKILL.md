---
name: cine-multicam
description: Use when the user drops or points at a local talking-head or performance video and wants the cinematic multi-camera edit prompt for Seedance 2.5 — one real take re-filmed by several virtual MOVING cameras (dolly, travelling, handheld close-ups, one fast precision arc, crane reveals) with hard cuts between them. Triggers on /cine-multicam, "cinematic multicam", "moving cameras on this take", a dropped .mp4 plus a cinematic-camera request. PT examples for reliability: "faz o prompt multicam cinematográfico desse vídeo", "bota câmeras em movimento nesse take", "edição multicâmera de cinema pro Seedance 2.5". NOT for /multicam (static-angle hard cuts, Google Omni) and NOT for /kinetic-multicam (camera whips + text supers).
---

# /cine-multicam: One Take → Cinematic Moving Multi-Camera

## Overview

Turns ONE real take into a Seedance 2.5 prompt that re-films it from several virtual cameras that PHYSICALLY MOVE — slow dolly in, lateral travelling, handheld close-up, detail insert, one fast precision arc, long-lens observational, crane reveal — with clean hard cuts between shots. The prompt **preserves the uploaded source video**: performance, dialogue, timing, lip sync and original audio all frozen; only the cinematography changes. It does NOT describe or regenerate the scene.

Sibling skills, never mixed: `/multicam` cuts between STATIC angles (Google Omni); `/kinetic-multicam` TRAVELS between locked positions with whips + text supers (Seedance 2.0 Fast). This skill cuts hard BETWEEN shots while the camera moves WITHIN them, adds a dramaturgical arc and per-rig physical imperfections, and carries no text layer. It is the long-take sibling: sweet spot ~15–30s (the others shine under 15s).

**TEMPLATE STATUS: EXPERIMENTAL v0.1.** Derived from a third-party Seedance 2.5 guide; one live generation so far (2026-08-18), which produced the first countermeasure (see the table at the end). Not yet production-validated in-house (the siblings' templates earned FROZEN status through dated real generations — this one hasn't). Shot design varies per video, so verification is structural, not byte-frozen. When a generation misbehaves, record the user's defect report verbatim: those reports become the v2 countermeasure table.

Core principle: **the skeleton's load-bearing sentences are fixed; the shot list is designed per video from what actually happens in it** — eyes (frames) + ears (word timestamps) together, never audio alone.

**Plug and play: the video is the only input.** The delivered prompt must run on a bare upload — source video in, prompt pasted, done. Never require the user to produce, crop or attach face references or any other asset; the base video already carries the identity, and the prompt says so explicitly.

## Input

Local video file only (the user's own footage) — and nothing else. **The base video is the only asset the user ever provides**: facial identity is taken from the footage itself, never from attached reference images. If the user only has a URL, ask them to save it locally first. If more than one video could be "the video", ask — never guess via `ls -t`.

## Step 0 — Preflight (first run, or on any missing-tool error)

```bash
python "<this skill's base directory>/scripts/check_env.py"
```

Relay anything missing with its install command; never install without permission. If it passed recently in this session, skip to Step 1.

## Step 1 — Ingest

```bash
python "<this skill's base directory>/scripts/beats.py" "<video path>"
```

Report `LANGUAGE` and `DURATION` to the user. Flags: `--cuts N` (shots − 1), `--language <code>`, `--force`, `--model medium`. Only ever transcribe through beats.py — its Whisper JSON cache (`<video stem>.json`, model `small`) is shared with the sibling skills; ad-hoc whisper runs with other models/formats fork the cache and litter the video's folder.

Then extract frames at 1 fps into a namespaced dir (`frames_<slug>/` without the prefix belongs to /videowatch and /reel-grab at other fps rates — reusing it blends incompatible frame sets):

```bash
mkdir -p "<video dir>/frames_cine_<video-slug>" && ffmpeg -y -loglevel error -i "<video>" -vf fps=1 "<video dir>/frames_cine_<video-slug>/frame_%04d.jpg"
```

## Step 2 — Breakdown (eyes + ears together)

Read ALL the 1 fps frames alongside `WORDS` — frame `k` covers second `k−1`. Never analyze audio alone (the observed failure of the audio-only siblings: they cannot see gestures, objects or wardrobe). Open the breakdown with an honesty header: `Frames analyzed: N of M`.

Produce the breakdown table: time range → spoken phrase → visual event (gesture, gaze shift, object interaction, posture change, framing change).

**Base-video fitness triage** (the guide assumes one clean take; check reality):
- Built-in cuts, wardrobe/background/lighting swaps? → list them frame-accurately; they become a `BASE VIDEO STRUCTURE` section and cut-point candidates. Warn the user this is advanced use — the method's home turf is a single continuous take.
- Burned-in captions, REC overlays, watermarks? → `BURNED-IN GRAPHICS` section: locked in screen space, unchanged by new angles. Warn: burned-in text is the top drift risk on new viewpoints.
- Ending loops into the opening (common in reels)? → the closing shot should resolve toward the opening framing instead of the default crane-out.

**Zoom pass**: for each candidate cut point (beats.py `NAIVE_CUTS` + visual events), pin the exact action moment with 2–3 extra frames:

```bash
ffmpeg -y -ss <T> -i "<video>" -frames:v 1 -q:v 2 "<video dir>/frames_cine_<video-slug>/zoom_<T>s.jpg"
```

## Step 3 — Shot design (judgment; the scripts only report facts)

`NAIVE_CUTS` is a deterministic first guess — **never deliver it unrefined.** Design the shot list:

- Shot count by duration: ≤12s → 4–5; 12–20s → 5–6; 20–30s → 6–8; >30s → warn (the technique shines on 15–30s) and design for the strongest window or expect truncation.
- Cuts land on phrase starts or at the START of a silence (round the previous word's end up to one decimal: word ends 3.98 → cut at 4.0), never mid-word; Whisper's hyphen-split words count as ONE word. A frame-verified visual event (gesture start, object pickup, built-in swap) may override the naive window — motivated beats mechanical.
- **Semantic cuts**: when the speech names something visible ("this camera", "these cards"), the insert or reframe lands on those words.
- Arc: default CALM → CURIOUS → INTIMATE → DETAIL → ONE DYNAMIC SURPRISE → OBSERVATIONAL → EXPANSIVE — adapt it to the video (loop-ending videos resolve to the opening framing; a video's own escalation can invert the arc). Every shot gets a FUNCTION (intimacy / reveal / detail / energy / observation / calm), not just a look.
- **Contrast rule: at most ONE dynamic-surprise move** (the fast precision arc or equivalent). If everything is spectacular, nothing is.
- Durations uneven, each shot ≥ ~2s, timecodes chained to one decimal, first at 00:00.0, last ending exactly at `DURATION` rounded to one decimal.
- **Double anchor**: every shot body ties its timecode to an action or spoken moment ("as he lifts the card", "while she turns to the window").
- Screen direction: keep the subject's eyeline consistent; when crossing to the opposite side, say so deliberately — never flip orientation in a disorienting way.

## Step 4 — Present, then MANDATORY checkpoint

Show the user, in this order:
1. Two lines on how it works: the prompt freezes the performance and audio; several virtual moving cameras re-film the same moment, and the edit hard-cuts between them — that's why it looks like a real multi-cam shoot.
2. The breakdown table + any triage findings (built-in swaps, burned-in graphics, loop ending).
3. The proposed shot list, each shot justified (which phrase/gesture motivates the cut, its function in the arc, which one is the dynamic surprise).
4. The skeleton below, still with its `[...]` zones.

Then ask (AskUserQuestion; plain chat if unavailable) **before filling anything**:
- Accept the shot list and timestamps, or adjust?
- Accept the arc/energy? Which shot is the dynamic surprise — or none?

Never skip this checkpoint or deliver before it is answered — even if the user seems in a hurry, or away. The observed baseline failure is shipping a finished prompt unchecked; present and wait.

## Step 5 — Fill the skeleton

Mutate ONLY: the shot headers + bodies (designed in Step 3); `[N]` and the arc line in CAMERA RHYTHM; the IMPERFECTIONS lines (keep only the rigs actually used); the tone sentence in FINAL FEEL; subject words ("The man"/"his" → whoever is on screen); the CRITICAL variant; the optional sections. Everything else is load-bearing — reproduce it exactly, including the negatives list.

CRITICAL variants (pick by what the video actually contains):
- **With dialogue** — as in the skeleton below.
- **Person, no dialogue** — replace the first CRITICAL line with: `Preserve the exact original performance, timing, gestures, actions, body movement, object interactions and original audio. Do not introduce dialogue or artificial speech. The ORIGINAL AUDIO must continue seamlessly across every cut.` In CONTINUITY, replace the mouth/voice sentences with `The original audio never restarts.`
- **No people** — replace it with: `Preserve the exact original movement, object positions, environmental behavior, timing and chronological sequence. The ORIGINAL AUDIO must continue seamlessly across every cut.` and adjust CONTINUITY the same way.

Optional sections (from triage; placed between CRITICAL and CAMERA SEQUENCE, in this order):
- `BASE VIDEO STRUCTURE` — frame-accurate list of the base video's own cuts/swaps, ordered preserved: `Preserve every built-in cut and swap exactly as content; never smooth, fix or beautify them.`
- `BURNED-IN GRAPHICS` — `Keep all burned-in captions and graphics locked in screen space, unchanged by the new camera angles.`

## Step 6 — Verify, save, deliver

Save as `<video basename>_cine_multicam_prompt.txt` next to the video, then:

```bash
python "<this skill's base directory>/scripts/verify_prompt.py" "<saved .txt>" --duration <DURATION>
```

It must print `PASS` (structure, chained timecodes summing to the duration, one dynamic max, no sibling tokens, negatives intact). Fix and re-run on `FAIL`; take its `WARNING`s back to the user if they touch anything they chose. Deliver the prompt in a fenced code block. Close with usage: upload the source video into **Seedance 2.5** and paste the prompt — nothing else to attach, no reference images, no extra assets — plus the experimental notice: *this template is v0; if the generation drifts identity, morphs a cut, resets a gesture or restarts audio, report exactly what broke — each report hardens the next version.* The prompt body is ALWAYS in English, whatever language the conversation or video is in.

## The canonical skeleton (EXPERIMENTAL v0 — load-bearing lines are fixed)

```
Edit the attached BASE VIDEO.

CRITICAL
The man must CONTINUE SPEAKING throughout the entire video exactly as in the original base video. Preserve his exact dialogue, voice, timing, lip sync, expressions, gestures and body movement. The ORIGINAL AUDIO must continue seamlessly across every cut.
Think of this as ONE uninterrupted speaking performance filmed simultaneously by several different cameras.
THE PERFORMANCE NEVER CHANGES. ONLY THE CAMERA AND EDITING CHANGE.
Preserve the same man, clothing, [room, furniture, background], lighting and color.
His facial identity must be taken entirely from the BASE VIDEO itself and stay identical from every new viewpoint.

CAMERA SEQUENCE

[MM:SS.d]–[MM:SS.d] — [SHOT NAME]
[Shot body: start position → movement → speed → trajectory → end position. Double anchor ("as he ..."). What continues from the original performance. One imperfection detail. 2–4 sentences.]

[... 4–8 shot blocks, chained, uneven durations, summing to the exact video duration ...]

CAMERA RHYTHM
Controlled, cinematic, easy to read. No constant cuts. Use [N] distinct shots of uneven durations. Progression: [ARC]. Clean hard cuts only — no transitions, no morphs, no artificial effects.

REAL CAMERA IMPERFECTIONS (occasional, almost subconscious — never constant, never exaggerated)
Handheld: subtle irregular micro-movement, tiny framing corrections, occasional momentary soft focus.
Dolly/travelling: slight physical vibration, natural acceleration and deceleration.
Long lens: subtle telephoto vibration, minor focus breathing, slightly late reframing.
Fast precision moves: precise trajectory, real acceleration, natural motion blur, tiny settling movement when stopping.
Crane: smooth physical inertia, subtle vibration during movement.

CONTINUITY — ABSOLUTELY CRITICAL
Every shot represents the exact chronological moment occurring in the BASE VIDEO. Nothing resets because of a camera cut. Actions and gestures never repeat. Object interactions never restart. Dialogue and audio never restart. When his face is visible, his mouth matches the exact words at that timestamp. When his face is out of frame, his original voice continues normally. All shots respect the original screen direction: his eyeline stays consistent, and camera positions never flip him to the opposite side of the frame in a disorienting way. Imagine [N] real cameras filming the SAME performance simultaneously and the editor simply switching between them.

FINAL FEEL
[One or two tone sentences matched to the video's world.] The camera should enhance the performance, never compete with it.
Same scene. Same person. Same performance. Same dialogue. Same voice. Same timing. ONLY THE CINEMATOGRAPHY CHANGES.
No new dialogue. No replacement voice. No silent montage. No new actions, characters or objects. No camera equipment, rigs or crew visible in frame. No music. No subtitles. No identity drift. No slow motion. No speed ramps. No time remapping.
```

## Movement presets (offered at the checkpoint; feelings from the source guide)

| Preset | Feeling | Body wording seed |
|---|---|---|
| Slow dolly in | intimacy, attention | `Perform a very slow, elegant physical dolly in, starting at [distance] and ending [closer], keeping [subject] near the center of frame` |
| Lateral travelling | energy, parallax | `Smooth lateral travelling [left/right] around [subject]; foreground elements create natural parallax` |
| Handheld close-up | intimacy, realism | `Close-up, slightly off-axis. Subtle irregular handheld movement, tiny operator breathing, small framing corrections` |
| Detail insert | emphasize an action | `Close detail of [hands/object]. Very short, slow travelling move. Shallow depth of field. [Subject]'s voice continues while the face is out of frame` |
| Precision arc (THE dynamic one) | precision, surprise | `The one noticeably dynamic move. A precision camera move pulls [backwards / upward / around] [subject], curving along a single arc, fast but elegant, accelerating then decelerating naturally, with realistic motion blur at the fastest point, and a tiny settling movement when it stops` |
| Long-lens observational | candid, documentary | `Viewpoint from farther away, longer lens, filmed partially through foreground elements; subtle telephoto vibration, tiny late reframing` |
| Crane up + pull back | reveal, scale, ending | `Smooth crane up combined with a gradual dolly back, slowly revealing [environment]; finish on a slightly asymmetrical wide composition` |
| Static wide | calm, contrast | `Locked-off wide shot; [subject] centered, still performing; the frame simply observes` |
| Rack focus | redirect attention | `Focus shifts deliberately from [A] to [B] and settles` |

**Standard cinematography vocabulary is fine** — dolly, travelling, crane and long lens all generate correctly. The ONE exception is a robotic arm: naming it renders it as a physical prop in the scene. Write `a precision camera move` instead and describe the trajectory. See the countermeasure table at the end.

## Do NOT (observed failure modes this skill exists to prevent)

- Do NOT write a generative scene-description prompt — character sheets, setting paragraphs, "CAM A/B/C" lists. That recreates the scene from text and guarantees identity drift. The template preserves the uploaded take.
- Do NOT paste the dialogue or any transcript into the prompt (no `DIALOGUE MAP`, no quoted lines). The observed baseline failure: a word-timed transcript pasted in — it invites the model to REGENERATE the speech instead of preserving the source audio. The verifier rejects unknown sections for exactly this reason.
- Do NOT write "robot arm" or "robotic arm" anywhere in the prompt. Observed in a live generation: "a precision cinema robot arm pulls backwards" rendered an actual robotic arm into the scene as a physical prop. The validated replacement keeps the sentence and swaps only the machine: `a precision camera move pulls backwards, rises slightly and curves around him`. `verify_prompt.py` fails on both spellings. Every other cinematography term — dolly, travelling, crane, jib, long lens — generates correctly and stays.
- Do NOT ask the user for face reference images, or tell them to crop or attach any asset. The skill is plug and play: base video in, prompt out. Identity comes from the footage, and the skeleton's identity line says exactly that.
- Do NOT skip the checkpoint or deliver before it is answered — the observed baseline shipped a finished prompt without ever asking. "The user is in a hurry / away" does not waive it; present and wait.
- Do NOT transcribe outside beats.py (no ad-hoc whisper models, formats or output dirs — the observed baseline forked the cache with `large-v3-turbo --output_format all`). One cache: `<video stem>.json`, model `small`.
- Do NOT borrow the sibling templates. `* At [Xs]:`, "Hard cut to a extreme high angle" (multicam), `From [Xs] to [Xs]`, "kinetic super", "Whip the camera", "Instantly snap" (kinetic-multicam) have no place here; the verifier fails on all of them.
- Do NOT hand over `NAIVE_CUTS` unrefined, cut mid-word, or split mechanically into equal blocks — durations must be uneven and cuts motivated (phrase, gesture, or built-in swap).
- Do NOT write more than one dynamic-surprise shot, and do NOT go under ~2s per shot without the user choosing it at the checkpoint (the observed baseline shipped a 1.4s shot unasked; the verifier warns).
- Do NOT "fix" the base video: never smooth its built-in jump cuts, never beautify intentionally ugly segments, never treat burned-in captions as removable — they are content to preserve (triage, Step 2).
- Do NOT invent Seedance 2.5 specs (generation-length cap, resolution limits are unverified). If a generation truncates or refuses, record the facts for v2 instead of guessing workarounds into the prompt.
- Do NOT deliver without a `PASS` from `scripts/verify_prompt.py` on the saved file, and do NOT save under any name but `<video basename>_cine_multicam_prompt.txt`.

## Countermeasure table (defects reported from live generations)

Each row is a real defect a user reported after generating, plus the fix now baked into the skill. This is how the EXPERIMENTAL template hardens — never delete a row, and add one every time a generation misbehaves.

| Reported defect | Date | Countermeasure |
|---|---|---|
| Naming the rig ("a precision cinema **robot arm** pulls backwards…") made the model render an actual robotic arm into the scene as a physical prop. | 2026-08-18 | Swap the machine for the move, keeping the sentence intact: **`a precision camera move pulls backwards, rises slightly and curves around him`** — user-validated, generated correctly. `verify_prompt.py` fails on "robot arm" and "robotic arm"; the negatives list carries `No camera equipment, rigs or crew visible in frame.` |
| *(scope note, not a defect)* The first fix banned the whole equipment family — crane, dolly, jib, steadicam, gimbal, tripod, drone, slider — on the theory that any rig noun could render as a prop. **None of them ever failed**, and replacing them with periphrasis made the prompt vaguer. Reverted. | 2026-08-18 | Ban only what a real generation broke on. If `crane` or `dolly` ever renders as a prop, add a row then. |
