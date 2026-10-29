# Backdrop extraction iteration notes

The initial headless import used default XDG locations that are not writable in
this executor. It produced cache/settings errors, then was rerun successfully
with explicit writable temporary XDG directories. This invocation failure is not
a successful clean import.

The first focused removal probe waited a process frame after removing the view.
FreightCradle legitimately completed its deferred cargo spawn in that gap, so the
physical-topology comparison was inconsistent. The removal check now compares
immediately. Independent review additionally required all original/new room
comparisons to await deferred freight initialization and assert cargo exists.
The final focused suite has 97 passing checks per rate.

Independent pre-native inspection found that an ALWAYS-process harness root
would keep inherited test rooms running despite global pause. Before native
execution, each test SubViewport became PAUSABLE; clock stability, valid image
content, clear-output hiding, real visible contour segments, precise geometry
and complete matrix/peer-isolation assertions were added.

The first native matrix produced 98 exact comparisons and six passing reuse
checks, but expanded native debugger inspection revealed real renderer errors:
`!viewport->canvas_map.has(p_canvas)` at viewport_for. The test harness assigned
canvas_transform before adding the SubViewport to the tree. The old report and
source manifest remain explicitly superseded as
room_backdrop_pre_canvas_registration_native_pixels.json and
room_backdrop_pre_canvas_registration_sources.json. The native diagnostic
screenshot is native_backdrop_pixel_diagnostics_desktop.jpg.

Independent Godot 4.6.3 source review confirmed the harness-only remedy: add the
SubViewport first, then set canvas_transform. Godot stores and reapplies that
transform during tree entry, so there is no claim that the old images were
miscropped. They nevertheless do not establish a clean native run. Production
view/room code did not change. Final acceptance requires the fresh native matrix
on the corrected frozen source plus inspected native diagnostics.

Official implementation references:
https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/scene/main/viewport.cpp
https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/servers/rendering/renderer_viewport.cpp
