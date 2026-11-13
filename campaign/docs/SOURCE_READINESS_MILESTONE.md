# Source readiness milestone

This local candidate starts at published `7f950e3` and cherry-picks frozen
`dc1f951` without code edits. Every non-documentation tracked file matches
`dc1f951`. The mutable smell experiment is not included.

## What changes for the player

- Nonphysical objective captions show E/Y only when the existing interaction
  selector actually selects that usable objective. Distant objectives say
  APPROACH; identity, prerequisites and physical-method descriptions remain.
- Actual local ladder contact can teach W/S before attachment. This is a
  body-contact clue, not remote ladder geometry or a promise that climbing can
  interrupt a busy combat action. Attached ladder instructions retain priority.

No movement, selection radius, layout, saves, audio or sense-choice changes.
See [responsibility mapping and headless checks](INTERACTION_READINESS.md).

## Source is not the current Windows download

Use Godot 4.6.3 to open this checkout's `project.godot` and press F5, or follow
[the source quickstart](PC_QUICKSTART.md). The existing
`MOKSHA-Windows-x64-ead13af.zip` remains built from `ead13af`, with gameplay
runtime `3d7786b`. Downloading or running that archive does not silently acquire
these new prompts. Its frozen hashes and bounded acceptance remain in the
[Windows release record](WINDOWS_EAD13AF_RELEASE.md). No new export is claimed.

## Evidence status

The frozen readiness implementation has 1,173 reported headless assertions
across its new and inherited presentation/contact checks. No engine was rerun
for this documentation integration. A scripted known-route native key-ladder capture completed normal exit 0,
reached only the key (1/4 required goals), with no deaths and health unchanged
at 75. Independent full-size pixel review accepted the bounded UI gate:

- Frame 465: local W/S ladder-contact hint before attachment.
- Frame 687: world caption APPROACH · RECOVER.
- Frame 827: E · RECOVER and selected action prompt while still on the ladder
  within reach, not standing on the ledge.
- Frame 910: COMPLETE and goals 1/4.

The unchanged global NEXT text still includes informational [E] at a distance.
This is world-caption and selected-action readiness, not removal of E from
all HUD text. The test is scripted actual InputEventKey input through the
normal sampler, not fresh-user or human usability proof.

Portable film: `MOKSHA-Scripted-Key-Ladder-Readiness-dc1f951-H264-AAC.mp4`,
5,761,737 bytes, SHA-256
`e59d0dd71cb7130dd7d7746f5c529a2a5f5331298d8056a7bc0aed6870c9c9ac`.
The full raw timeline is 1,040 frames / 17.333 seconds, with no duplicate or
dropped frames and successful full decode. A 72-pixel external label identifies
the scripted test above the uncropped 1280×720 viewport; no cuts, speed changes
or gameplay overlays. Original engine audio was transcoded to AAC without mix
changes; no audible-mix listening acceptance is claimed.

The native capture took 101.054 wall seconds. This is not realtime performance,
full Market/campaign completion, a native controller-button review, Windows
execution or a packed-build test. The observer allowed 0.5 seconds for disposal,
so this is not immediate ordinary-close leak proof. Preserved diagnostics include
VSync/low-disk warnings and verbose controller-mapping/custom-cursor startup
messages; no errors were reported.

Earlier known-route and fresh screenshot-only AI clips remain evidence for
`ca7762b`, not footage of these new prompts. The nine-case text review remains
bounded to `3d7786b`. Historical receipts are preserved rather than relabelled.
