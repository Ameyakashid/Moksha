# Bounded native input review

Runtime: `fe9936a2ecfde8a727ac2131801f3b9b22929d61`, Godot 4.6.3,
Linux desktop, OpenGL compatibility/llvmpipe. This was agent-directed desktop-key
input chosen from fresh screenshots, not the campaign route script, a human
playthrough, or a recorded full-level completion.

A normal title launch selected Neutral and started Rainline. Observed actions:
walking, jumping onto the first raised deck, crossing a crate, visible guard
presentation, sound-tap visual feedback, ladder ascent to the roof, opening and
closing the field journal, pause, and district reset. Reset returned the player
to the district start with 60/60 HP. Journal/pause text remained readable and
no stuck-input state or blocked traversal was observed in this short sample.
The session ended after roughly a minute of active game time; tool inspection
pauses make this unusable as human pacing evidence. It does not prove combat
balance, an enemy kill, objective completion, or the remainder of the level.

The normal game window closed. Its log contains no retained-resource/ObjectDB
shutdown warning. This does not erase the earlier controlled health fixture's
separate retained-resource warning or prove a long-session leak cannot exist.
Tracked source was clean and unchanged afterward.

Environment limitations: V-Sync changes were unsupported. ALSA could not open an
audio device; Godot reported that error and fell back to its dummy audio driver.
No audible-mix judgment was possible. The native launch log is deliberately not
called error-free. A first launch attempted from the isolated command environment
had no display; the successful check ran from the actual desktop terminal.
