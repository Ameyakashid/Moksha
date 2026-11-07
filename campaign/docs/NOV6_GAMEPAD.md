# Campaign controller navigation — November 6, 2026

The campaign now has a controller-only path through its title, story panels,
field journal, pause/reset, sight decision, level upgrades, endings, defeat, and
checkpoint Continue. This is an additive campaign adapter. The original shared
actor, its movement/combat code, and its existing InputMap remain unchanged.
Default movement and combat now accept any connected controller ID, including
when the operating system assigns a pad something other than device zero.

## Controls

Labels use Godot's standard ABXY controller layout, not detection of a specific
controller brand. `Back` may be labelled View or Select on a physical device.

| Screen | Controller input |
| --- | --- |
| Title | D-pad left/right: choose starting lens; A or Start: new campaign; X: Continue when a valid checkpoint exists |
| Intro | Fresh A or Start: skip |
| Playing | Left stick or D-pad: move/climb; A: jump/air jump; down + A: drop/dive; X: strike; LB: shield; RB: roll |
| Playing, campaign commands | Y: interact; B: sound/sonar tap; Back: journal; Start: pause |
| Field journal | D-pad left/right: page; Back or B: return |
| Recovered archive | A, B, or Y: return |
| Pause | Start or B: resume; X: reset current district; Y: title |
| Sight offer | X: trade sight; B: keep sight |
| Level upgrade | X: Force; Y: Agility; B: Vitality |
| Final decision | X: Public Record; Y: Local Custody |
| Defeat | A: retry district; Y: title |
| Completed campaign | A, Start, or Y: title |

The keyboard remains available at all times. Menu directions intentionally use
the D-pad. Left-stick movement remains the original actor's mapping; this adapter
does not add analog menu repeat or change its deadzone.

## Input and safety contract

- `campaign/input/controller_bindings.gd` creates private copies of complete
  default keyboard/controller actions, widening only the controller device filter.
  Godot owns aggregate held/pressed/released edges. Original action events,
  identities and deadzones are never edited. Custom original mappings remain
  authoritative, including changes made while the campaign is running.
- Helpers are created only when the campaign enters its ready lifecycle. Held
  controls are suppressed on mounting and re-entry until released. Private actions
  are removed on exit only if their complete contents remain unchanged; actions
  explicitly edited by another caller are left intact. Off-tree focus/disconnect
  callbacks cannot pause a detached campaign.
- `campaign/input/gamepad_navigation.gd` is a campaign-owned Node. The campaign
  binds/adds it before its inherited title/HUD setup. It continues to process
  input while the scene tree is paused.
- Intentional controller button presses select controller prompts. Left-stick
  motion selects them only at an absolute value of at least 0.65. Connections,
  releases, small stick motion, the unused right stick, and mouse motion do not
  switch the visible prompt device. Keyboard or mouse-button presses restore
  keyboard prompts.
- The HUD receives `input_device` as `keyboard` or `controller`. Its campaign-only
  typed owner validates that field. World objective captions read the same
  adapter property. Existing keyboard prompts are still the default.
- Each controller button is tracked per device. A press must be released before
  it can accept another menu command. Held A cannot start and skip the intro in
  the same press, and held X cannot retry/choose twice.
- Menu commands call the campaign's existing key-handler boundary with a local
  command object. They never inject a keyboard event into global Input or create
  actor-action edges. The campaign's existing held-input gate prevents jump,
  strike, shield, roll, and movement from leaking out of menus and room changes.
- Disconnecting the controller that most recently selected controller input
  invokes the campaign's focus-loss safety pause. Keyboard prompts return.
  Reconnecting does not resume automatically. Existing journal/choice screens
  stay intact; unrelated controller disconnection does not pause the run.
- Controller routing does not change saves, progression choices, weapon values,
  action cooldowns, or damage authority. Continue uses the existing validated
  checkpoint and cannot start without one.

## Reproducible regression

In Bash on Linux, run from the project root using Godot 4.6.3. Each run must use a fresh HOME/XDG
sandbox because the Continue check intentionally writes and reads a checkpoint.
The sandbox is temporary test data, not the player's normal save directory.

```sh
for hz in 60 120; do
  run_dir="$(mktemp -d /tmp/moksha-gamepad-${hz}-XXXXXX)"
  mkdir -p "$run_dir"/{home,cache,data,config}
  if ! HOME="$run_dir/home" \
  XDG_CACHE_HOME="$run_dir/cache" \
  XDG_DATA_HOME="$run_dir/data" \
  XDG_CONFIG_HOME="$run_dir/config" \
  timeout 120 godot --headless --fixed-fps "$hz" --path . \
    --script res://campaign/quality/nov6_gamepad_navigation.gd \
    -- --hz="$hz" > "$run_dir/test.log" 2>&1; then
    cat "$run_dir/test.log"
    exit 1
  fi
  cat "$run_dir/test.log"
done
```

The completion marker is `NOV6_GAMEPAD_NAVIGATION_RESULT`. Accept a run only when
its exit status is zero, `passed` is true, and its log contains no script/engine
errors. The November 6 implementation run passed **63 checks at 60 Hz and 63 at
120 Hz**. The result includes individual checks and an explicit coverage limit.

All acceptance presses use `Input.parse_input_event` with
`InputEventJoypadButton`, `InputEventJoypadMotion`, or real keyboard event objects,
followed by the real scene-tree event pipeline. The tests do not call the adapter's
command mapper or the campaign's menu handler directly, and never use
`input_override`. They cover controller debounce, actor movement/combat, journal
paging, choice/upgrade/ending branches, retry, checkpoint Continue, keyboard
coexistence, noisy sticks, active/inactive controller disconnects, and input
rearming after menus.

Some tests explicitly create an objective, place a modal state, or invoke defeat
to isolate the command under test. They establish correct menu acceptance and
state transitions, not traversal of the authored campaign or automatic arrival
at every decision. Disconnect tests emit Godot's connection signal and keep a
synthetic held direction until release so the resume safety gate is exercised.

The separate `campaign/quality/nov6_controller_devices.gd` fixture exercises
actual actor movement, climbing, jumping, guard, roll and strike on synthetic
devices 0, 1 and 3. It emits `NOV6_CONTROLLER_DEVICES_RESULT` with 213 checks per
rate and can run unchanged outside an exported PCK. The aggregate
`tools/verify_nov6.py` command runs both controller fixtures at matched fixed
and physics rates, alongside keyboard and paused-release regressions.

### Authoring and integration boundary

Explicit campaign `input_override` dictionaries still bypass device sampling
unchanged. Direct `Input.action_press/release("cp_*")` or an `InputEventAction`
addressed to an original `cp_*` action is not mirrored into private aliases.
Use the existing explicit override for simulated campaign input, or real
keyboard/joypad events for device-path tests. This does not change the original
actor or its standalone demo's input contract.

## Verification limits

These are synthetic input events in Godot's real event pipeline, not physical
USB/Bluetooth controller tests. They do not certify SDL device discovery,
platform-specific mappings, hotplug drivers, wireless disconnect behaviour,
rumble, target-hardware performance, or console certification. Controller labels
are ABXY conventions. A native visual/keyboard review is also not evidence of
physical controller compatibility. Full authored traversal and real-device
comfort testing remain separate checks.
