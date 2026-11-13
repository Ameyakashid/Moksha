# Play MOKSHA on a Windows PC

## Which version do you want?

Current Windows: `MOKSHA-Windows-x64-596b884.zip`, runtime `891f781`, includes
smell exchange and readiness prompts. Its four matching part ZIPs are a delivery
form of that same complete ZIP. See [release hashes and 62-stage scope](WINDOWS_596B884_RELEASE.md).
For editable source, clone and use Godot below. Source596 was verified published;
check your own checkout because later source changes do not update old downloads.

Close the game and back up the entire save folder before changing builds. This
release supports checkpoint v4; old ead13af/3d and 23a downloads are historical and
cannot read v4. Restore a matching old backup for an old build, never relabel a
save version. Native Windows/CMD execution remains unverified.

## Portable Windows build

Use the delivered Windows x64 ZIP, or reconstruct it from every ZIP in its
Windows part set using the included `Assemble-MOKSHA.cmd`. Extract the complete result,
open `MOKSHA-Windows`, and run `MOKSHA.exe`. Keep `MOKSHA.pck` beside it. You do
not need Git, Python, an editor, an installer, or administrator access for this
portable build. Do not try to run the game inside a ZIP.

Use the commit named by your ZIP and its `BUILD_PROVENANCE.json`. The earlier
November 12 `fe9936a` package and November 6 `c73159b` package are preserved
historical deliveries, not names for every later source revision. Use all parts
from the same dated/hash-labelled build and extract into a new folder. Later
source changes do not automatically update an already-delivered executable.
See the [historical release verification record](../quality/nov12_release_validation/)
and [extended source changes](NOV12_EXTENDED_CHECKPOINT.md).

## Clone and run the editable source

A clone contains only what has actually reached GitHub. It does not fetch later
Library checkpoints or update an older download. Check `git log -1 --oneline`
and the delivered source checkpoint instructions before assuming the latest
features are present. See [the current source/release distinction](CURRENT_PLAYABLE_STATE.md).

1. Install Git if you do not already have it. Sign in with a GitHub account that
   has access to the private repository, then run:

   ```bat
   git clone https://github.com/Ameyakashid/Moksha.git
   cd Moksha
   git rev-parse HEAD
   ```

2. Download **Godot 4.6.3, standard Windows x86-64**, from Godot's official
   release archive: <https://godotengine.org/download/archive/>. Extract it to a
   folder of your choice. The .NET edition and export templates are not needed
   to play the source project. The original validated engine version is
   `4.6.3.stable.official.7d41c59c4`.

3. The editor route is the simplest: open Godot, choose **Import**, select this
   repository's `project.godot`, let the asset import finish, and press **F5**.
   The main scene is the five-level campaign, `campaign/campaign.tscn`.

   Or use the included launcher from Command Prompt, supplying your actual
   executable path (the path below is an example):

   ```bat
   Play-MOKSHA.cmd "C:\Tools\Godot\Godot_v4.6.3-stable_win64_console.exe"
   ```

   It checks the engine version, imports local assets, then starts the game.
   It also accepts `godot.exe` or `godot4.exe` already on your PATH. It makes no
   downloads, changes no PATH/security settings and needs no administrator
   access. First import can take longer; subsequent runs reuse `.godot/`.
   If it reports an error, use the editor route and keep the error message.

This is a Godot project, not a Python or Node application. No `pip install`,
`npm install` or virtual environment is needed to play. The optional Python
quality/build tooling is for development and is separate from game startup.

## First controls and saves

On the title, choose **1** Neutral, **2** Strength or **3** Agility, then press
**Enter**. **C** continues a checkpoint. Move with **A/D**, jump with **Space**,
strike with **J**, guard/parry with **K**, roll with **Shift**, use with **E**,
and tap sonar with **Q**. **Esc** pauses. Controller prompts and all controls
are in the root README and [controller guide](NOV6_GAMEPAD.md).

Saves are in Godot's normal user-data folder, not the Git checkout. See
[local playtesting](LOCAL_PLAYTEST.md) for the exact Windows location, checkpoint
semantics and how to preserve results before another run.

## What has and has not been tested

The source import/startup sequence and focused game tests are run on Linux with
Godot 4.6.3. The CMD launcher is source-reviewed and checked structurally, but
native Windows execution remains unverified. Source and exported-game automated
routes are not a full human playthrough. The 15–20-minute-per-level pacing target
is still unverified. Do not disable antivirus or security policy if an unsigned
executable or script is blocked.
