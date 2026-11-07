# bf3 controlled native PCK captures

These 31 PNGs were produced from the exact c489 source / bf3 runtime PCK. Every
capture row reports error 0 and the completion marker is present. The desktop
session completed. All 31 PNGs were individually reviewed at full size: menus,
both device prompts, held-input hints, the separate checkpoint warning, and all
five blind pairs are readable, with no clipping or scenery leakage observed.
NATIVE_CAPTURE_RECEIPT.json binds the images, fixture, wrapper, log, PCK and source.

The native session used Linux X11/OpenGL compatibility with software llvmpipe,
Dummy audio, and disabled V-Sync. The known V-Sync warning is preserved. No script,
resource or leak warnings occurred in this controlled capture log. This is not a
claim about a separate ordinary keyboard/Alt-F4 smoke or general application exit.
No native Windows, audible output, hardware performance, physical-controller,
route traversal, or human-duration claim is made by these controlled fixtures.

The preparation manifest records native_session_launched:false for preparation;
the later receipt and capture log record the completed session. Original launcher
and wrapper paths are historical provenance, not portable launch commands. PCK,
engine binaries, cache files and user data are deliberately omitted. The real
resource working directory remained empty; there was no loose production fallback.

Run ../packed/verify_evidence.py to check both hash-indexed evidence folders.
