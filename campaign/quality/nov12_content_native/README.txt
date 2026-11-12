Native missing-content startup inspection

Godot4.6.3, native Linux OpenGL compatibility renderer (Mesa llvmpipe), isolated
HOME/XDG save/config/cache. Native run launched from desktop Terminal; screenshots
are actual viewport captures, not mockups or headless image reconstruction.

Reviewed error-normal-1180x663.png and error-small-640x360.png: heading, missing
file name, unchanged-save reassurance and restart instructions fully visible,
legible and unclipped. Black error background fills the viewport. Gameplay and
physics processing disabled. No production UI fix required.

Normal CLI requested1280x720 but desktop window manager produced1180x663; both
initial requested sizes were normalized to that size. Small capture was repeated
with Window.size explicitly set640x360 after startup and its actual pixel size
verified. Do not label the normal image a1280x720 capture.

capture.gd reproduces the small fixture with missing-content subclass and writes
the PNG to its first user argument. Use a native renderer, not --headless. The
normal fixture omitted the explicit size assignment. This checks the startup
failure view, not gameplay or Windows.
