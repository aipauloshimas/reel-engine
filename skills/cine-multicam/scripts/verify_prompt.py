#!/usr/bin/env python3
"""Verify a delivered cine-multicam prompt's structural invariants.

Unlike the sibling skills' byte-frozen templates, the cine shot design varies
per video — so this verifier checks STRUCTURE, not bytes.

Usage: python verify_prompt.py <delivered_prompt.txt> --duration <seconds>

PASS iff:
  - required sections appear in order: CRITICAL, CAMERA SEQUENCE,
    CAMERA RHYTHM, REAL CAMERA IMPERFECTIONS, CONTINUITY, FINAL FEEL;
  - the template's load-bearing sentences are present (performance lock,
    simultaneous-cameras framing, chronological-moment line, hard-cuts rule,
    the full negatives list);
  - 4-8 shot blocks with `MM:SS.d–MM:SS.d — NAME` headers: ascending, chained
    (end N == start N+1), first at 00:00, last == --duration (within 0.1s);
  - shot durations are not all equal (uneven-rhythm rule);
  - at most ONE dynamic-surprise shot (marked "noticeably dynamic");
  - no sibling-skill tokens (/multicam and /kinetic-multicam must never leak in);
  - no camera-equipment nouns (they get rendered as props in the scene).

Soft reports (warn, never fail): a shot missing an action anchor
("as he/she/they...", "when/while..."); no dynamic-surprise shot at all.
Exit 0 on PASS, 1 on FAIL.
"""
import argparse
import re
import sys
from pathlib import Path

TOL = 0.051          # chaining / start-at-zero tolerance (one-decimal timecodes)
DURATION_TOL = 0.15  # last shot end vs real video duration

SECTIONS = ["CRITICAL", "CAMERA SEQUENCE", "CAMERA RHYTHM",
            "REAL CAMERA IMPERFECTIONS", "CONTINUITY", "FINAL FEEL"]

# optional sections, allowed only between CRITICAL and CAMERA SEQUENCE, for base
# videos that are not one clean take (built-in jump cuts / burned-in captions)
OPTIONAL_SECTIONS = ["BASE VIDEO STRUCTURE", "BURNED-IN GRAPHICS"]

MIN_SHOT_WARN = 2.0  # cine grammar floor: shots under ~2s read as frenetic, not cinematic

REQUIRED_SENTENCES = [
    "Edit the attached BASE VIDEO.",
    "filmed simultaneously by",
    "THE PERFORMANCE NEVER CHANGES. ONLY THE CAMERA AND EDITING CHANGE.",
    "Every shot represents the exact chronological moment occurring in the BASE VIDEO.",
    "never restart",
    "no transitions, no morphs",
    "No new dialogue.", "No replacement voice.", "No silent montage.",
    "No new actions, characters or objects.", "No music.", "No subtitles.",
    "No identity drift.", "No slow motion.", "No speed ramps.", "No time remapping.",
    "No camera equipment, rigs or crew visible in frame.",
]

# tokens owned by the sibling skills; any of them here means a frankenstein prompt
SIBLING_TOKENS = ["* At [", "From [", "kinetic super", "Kinetic super",
                  "Whip the camera", "Instantly snap", "extreme high angle"]

# Camera-equipment nouns get rendered as PHYSICAL PROPS in the scene. Observed in a
# live generation (2026-08-18): "a precision cinema robot arm pulls backwards" put an
# actual robotic arm in frame. Describe the motion — trajectory, speed, physics — never
# the machine that would perform it.
RIG_NOUNS = ["robot arm", "robotic arm", "crane", "jib", "steadicam", "gimbal",
             "dolly", "tripod", "drone", "slider", "camera rig", "camera operator",
             "operator breathing"]

SHOT_HEADER = re.compile(
    r"^(\d{2}):(\d{2}(?:\.\d)?)[–-](\d{2}):(\d{2}(?:\.\d)?)\s+(?:—|--)\s+(.+?)\s*$")

ANCHOR = re.compile(r"\b(?:as|when|while)\s+(?:he|she|they|his|her|their|the)\b",
                    re.IGNORECASE)

# a standalone ALL-CAPS line that is not a known header is an invented section
# (the observed baseline failure: a word-timed DIALOGUE MAP pasted into the prompt)
CAPS_HEADER = re.compile(r"^[A-Z][A-Z0-9 \-–—&()'/+]{3,50}$")

DYNAMIC = re.compile(r"noticeably dynamic", re.IGNORECASE)


def fail(msg: str):
    print(f"FAIL: {msg}")
    sys.exit(1)


def to_seconds(mm: str, ss: str) -> float:
    return int(mm) * 60 + float(ss)


def main():
    ap = argparse.ArgumentParser(description="Structural verifier for cine-multicam prompts")
    ap.add_argument("prompt", type=Path)
    ap.add_argument("--duration", type=float, required=True,
                    help="real video duration in seconds (from ffprobe/beats.py)")
    args = ap.parse_args()

    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

    text = args.prompt.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    lines = text.split("\n")

    # -- sibling-skill frankenstein guard (checked first: it invalidates everything)
    for tok in SIBLING_TOKENS:
        if tok in text:
            fail(f"sibling-skill token found: {tok!r} — /multicam and /kinetic-multicam "
                 f"templates must never be mixed into a cine-multicam prompt")

    # -- camera-rig nouns become props in the generated scene
    low = text.lower()
    for noun in RIG_NOUNS:
        if noun in low:
            fail(f"camera-equipment noun found: {noun!r} — naming the rig makes the model "
                 f"render it as a physical object in the scene (observed: 'robot arm' put an "
                 f"actual robotic arm in frame). Describe the motion instead: trajectory, "
                 f"speed, acceleration, motion blur, settle")

    # -- required sections, in order
    positions = {}
    for i, line in enumerate(lines):
        for s in SECTIONS:
            if s not in positions and line.startswith(s):
                positions[s] = i
    for s in SECTIONS:
        if s not in positions:
            fail(f"missing required section: {s}")
    order = [positions[s] for s in SECTIONS]
    if order != sorted(order):
        fail(f"sections out of order (expected {', '.join(SECTIONS)})")

    # -- optional sections: allowed, but only before CAMERA SEQUENCE
    known = SECTIONS + OPTIONAL_SECTIONS
    for i, line in enumerate(lines):
        s = line.strip()
        if s in OPTIONAL_SECTIONS and i > positions["CAMERA SEQUENCE"]:
            fail(f"section {s} must appear before CAMERA SEQUENCE")

    # -- invented sections (e.g. a DIALOGUE MAP transcript) are forbidden
    for line in lines:
        s = line.strip()
        if not s or SHOT_HEADER.match(s):
            continue
        if any(s.startswith(k) for k in known):
            continue
        if CAPS_HEADER.match(s) and not any(c.islower() for c in s):
            fail(f"unknown section header {s!r} — the template has no such section. "
                 f"In particular, never paste the spoken dialogue or a transcript "
                 f"into the prompt: it invites the model to regenerate the speech "
                 f"instead of preserving the source audio")

    # -- load-bearing sentences
    for sent in REQUIRED_SENTENCES:
        if sent not in text:
            fail(f"missing required sentence: {sent!r}")

    # -- shot blocks live between CAMERA SEQUENCE and CAMERA RHYTHM
    seq_lines = lines[positions["CAMERA SEQUENCE"] + 1: positions["CAMERA RHYTHM"]]
    shots = []  # (start, end, name, body)
    current = None
    for line in seq_lines:
        m = SHOT_HEADER.match(line)
        if m:
            if current:
                shots.append(current)
            start = to_seconds(m.group(1), m.group(2))
            end = to_seconds(m.group(3), m.group(4))
            current = [start, end, m.group(5), ""]
        elif current is not None:
            current[3] += line + "\n"
    if current:
        shots.append(current)

    if not shots:
        fail("no shot blocks found under CAMERA SEQUENCE "
             "(headers must look like `00:04.2–00:07.6 — SHOT NAME`)")
    if not 4 <= len(shots) <= 8:
        fail(f"shot count {len(shots)} outside the 4-8 range")

    if abs(shots[0][0]) > TOL:
        fail(f"first shot must start at 00:00, not {shots[0][0]:.1f}s")
    for i, (start, end, name, _) in enumerate(shots, 1):
        if not start < end:
            fail(f"shot {i} ({name}) range is not ascending: {start:.1f} -> {end:.1f}")
    for i in range(len(shots) - 1):
        if abs(shots[i][1] - shots[i + 1][0]) > TOL:
            fail(f"shots {i + 1} and {i + 2} do not chain "
                 f"({shots[i][1]:.1f} vs {shots[i + 1][0]:.1f}) — every cut point "
                 f"must be shared by the shots on both sides")
    if abs(shots[-1][1] - args.duration) > DURATION_TOL:
        fail(f"last shot ends at {shots[-1][1]:.1f}s but the video duration is "
             f"{args.duration:.1f}s — the timecodes must sum to the full duration")

    durations = [round(end - start, 1) for start, end, _, _ in shots]
    if len(set(durations)) == 1:
        fail(f"all {len(shots)} shots have equal durations ({durations[0]}s) — "
             f"the rhythm rule requires uneven durations")

    dynamic_shots = [i + 1 for i, (_, _, name, body) in enumerate(shots)
                     if DYNAMIC.search(name + " " + body)]
    if len(dynamic_shots) > 1:
        fail(f"more than one dynamic-surprise shot (shots {dynamic_shots}) — "
             f"the contrast rule allows at most one")

    warnings = []
    for i, (start, end, name, _) in enumerate(shots, 1):
        if end - start < MIN_SHOT_WARN - 0.05:
            warnings.append(f"shot {i} ({name}) runs only {end - start:.1f}s — "
                            f"under ~{MIN_SHOT_WARN:.0f}s a shot reads as frenetic, "
                            f"not cinematic; merge it or stretch it unless deliberate")
    for i, (_, _, name, body) in enumerate(shots, 1):
        if not ANCHOR.search(body):
            warnings.append(f"shot {i} ({name}) has no action anchor "
                            f"('as he...', 'while she...') — double-anchoring "
                            f"timecodes to actions makes cuts land better")
    if not dynamic_shots:
        warnings.append("no dynamic-surprise shot — fine if chosen deliberately "
                        "at the checkpoint")

    print("PASS: structural invariants hold")
    print(f"shots: {len(shots)}, total {shots[-1][1]:.1f}s "
          f"(video {args.duration:.1f}s), durations {durations}")
    for i, (start, end, name, _) in enumerate(shots, 1):
        tag = "  <- dynamic surprise" if i in dynamic_shots else ""
        print(f"  {i}. {start:5.1f} -> {end:5.1f}  ({end - start:3.1f}s)  {name}{tag}")
    for w in warnings:
        print(f"WARNING: {w}")
    sys.exit(0)


if __name__ == "__main__":
    main()
