# Native review of f00bf23

A standalone Godot 4.6.3 Linux window rendered the actual game using Mesa llvmpipe. Direct-scene fixtures produced 61 district/start/goal views and 28 menu/sight views. These are visual fixtures, not campaign traversal. The preserved capture manifest identifies the full-resolution images by SHA-256; the image collection remains separate from this source archive.

All 32 district views were inspected for foreground readability, varied background treatment and landmark scale. The final menu set was inspected for keyboard/controller prompts, footer separation, choice text, save-error messages and blackout/sonar concealment. The final capture shutdown has no leaked-resource or orphan warnings.

An additional native keyboard attempt traversed part of Rainline using genuine movement, jumps, ladder climbing and combat controls. The operative took real incoming damage, eventually died, retried from the death menu and opened Pause. This is a partial manual input check, not a completed district or human campaign/pacing measurement.

The environment could not select hardware V-Sync or open an audio device. Both logs explicitly report those environment warnings and an ALSA initialization error before falling back to the dummy audio driver. Audible mix and target-machine performance were not verified. No native Windows execution or physical controller was available.
