# Ordinary-exit diagnostic: frozen b2e7f35

**Known non-blocking Linux Dummy-audio exit diagnostic. Not a clean-shutdown pass, and not a demonstrated Windows issue. No runtime cleanup hook added.**

## Actual packed game

One fresh native launch used the unchanged PCK from an empty resource directory, with no external fixture script. After visually confirming the title, an actual Alt-F4 closed the game with exit code 0. The complete warning/error remains in `native-ordinary-close.log`:

- ObjectDB instances leaked at exit.
- One resource still in use: `res://audio/ambience.wav` (AudioStreamWAV).
- AudioStreamWAV and AudioStreamPlaybackWAV each retained reference count 1. No leaked Node or campaign script was listed.

PCK SHA-256: `262f3685fa8c1ec4c34c363de77e1b6ed8a3023971a908e66556d01ad2467282`.

## Isolated controls

Six trials per cell; entries count processes with the WAV/playback diagnostic:

| Scope | Direct quit | Stop/free + 3 frames | Same + 250 ms |
| --- | ---: | ---: | ---: |
| Packed bare player | 6/6 | 6/6 | 0/6 |
| Unchanged inherited director | 6/6 | 6/6 | 0/6 |
| Unchanged original demo | 4/6 | 3/6 | 0/6 |
| Frozen campaign | 5/6 | 3/6 | 0/6 |
| Pure engine, no game assets/scripts | 6/6 | 6/6 | 0/6 |

Both no-play negative controls were 0/6. These 102 controls used headless Dummy audio with explicit playback, not native window-close input. The pure-engine resource is anonymous, so it has the same ObjectDB object pair but no resource-cache-path error. All 103 executions exited 0; exit code 0 does **not** mean warning-free shutdown.

The original director, demo and ambience are unchanged since baseline `632b6c9`. The director already stops players, clears their streams and empties its cache. Reproduction without game scripts/assets, and disappearance after retirement time, support an inherited engine-audio shutdown issue rather than a new campaign ownership leak. Another cleanup hook alone does not resolve it.

## Exact limits and preservation

Engine: **Godot 4.6.3.stable.official.7d41c59c4**. Native display: Linux **X11**. Audio: **Dummy**, no soundcard/listening verification. Renderer: **gl_compatibility**, OpenGL 4.5 Core, Mesa 25.0.7-2+deb13u1, **llvmpipe (LLVM 19.1.7, 256 bits)** software graphics. The native log also preserves the unsupported V-Sync-mode warning. Windows shutdown, hardware audio and target-hardware performance remain untested.

Do not suppress the ordinary-close warning or use fixtures that wait 250 ms as ordinary-close proof. No runtime patch is warranted for this release. A future close-interception workaround would change shutdown behavior and require native repeated-close/modal/audio checks plus full runtime/package regression.

`exit-diagnostic-evidence.tar.gz` is an immutable byte-for-byte copy of the original complete bundle, including 102 control logs, the native log, scripts, matrices, original provenance and detailed review. Its 114 internal SHA-256 entries were reverified. `provenance.json` distinguishes native PCK evidence from headless packed and pure-engine controls. `SHA256.json` authenticates every adjacent file except itself. No production runtime files changed.
