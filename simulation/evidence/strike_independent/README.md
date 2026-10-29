# Independent incoming-strike review evidence

The final report and logs record separate focused, adverse-callback and pause-fence
runs at 60/120 Hz. No production files were edited by the reviewer.

Standalone probe scripts are preserved byte-for-byte as .gd.txt evidence. To rerun,
copy them as .gd files into /tmp/moksha-strike-independent (their original test
location), then run Godot with the MOKSHA project as --path and the chosen /tmp
script as --script. Supply -- --hz=60 or -- --hz=120 and matching --fixed-fps.
Use writable XDG_DATA_HOME, XDG_CONFIG_HOME and XDG_CACHE_HOME locations.

These probes establish lifecycle/API boundaries, not fabricated gameplay success.
The project's incoming_strike_regression.gd supplies the actual input/contact cases.
