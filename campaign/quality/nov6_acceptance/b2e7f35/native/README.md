# Controlled native PCK capture evidence

These are exactly 31 controlled UI/sight fixture captures from the b2 PCK,
SHA-256 262f3685fa8c1ec4c34c363de77e1b6ed8a3023971a908e66556d01ad2467282.
All capture rows report error 0 and the completion marker is present. Every PNG
was reviewed at full size: no clipped menu text, footer/control overlaps, missing
asset artifacts, or visible scenery leaks in blind states were observed. Captions,
save warnings, and held-input guidance remained readable. NATIVE_CAPTURE_RECEIPT
records image hashes, dimensions, exact fixture/PCK identity, and review scope.

Rendering used native Linux X11/OpenGL compatibility with software llvmpipe.
Dummy audio was selected because there is no soundcard. V-Sync was disabled; the
known driver warning remains in capture.log. There are no script/resource/leak
warnings in this controlled capture log. This does not apply to a separate manual
Alt-F4 session, which produced an audio-exit resource warning under classification.

These controlled fixture images are not route traversal, physical-controller,
Windows, target-hardware performance, audible-output, or human-duration evidence.
The preparation manifest's native_session_launched:false describes preparation
only; the later capture receipt and raw log document the completed capture.
The original launcher/wrapper are retained as exact historical bytes with original
absolute paths. They are not portable launchers for this evidence-only folder.
The capture resources directory was empty; no loose production resource fallback
was used. PCK/engine binaries and caches are excluded. All raw evidence is unchanged.

Run ../packed/verify_evidence.py to verify both sibling evidence folders.
