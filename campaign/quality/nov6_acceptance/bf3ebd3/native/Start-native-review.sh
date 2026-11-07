#!/bin/sh
set -eu
export HOME=/workspace/scratch/fd16273ade4b/moksha-nov6-rehearsal-c489885/isolated/native_capture/HOME
export XDG_DATA_HOME=/workspace/scratch/fd16273ade4b/moksha-nov6-rehearsal-c489885/isolated/native_capture/XDG_DATA_HOME
export XDG_CONFIG_HOME=/workspace/scratch/fd16273ade4b/moksha-nov6-rehearsal-c489885/isolated/native_capture/XDG_CONFIG_HOME
export XDG_CACHE_HOME=/workspace/scratch/fd16273ade4b/moksha-nov6-rehearsal-c489885/isolated/native_capture/XDG_CACHE_HOME
EMPTY=/workspace/scratch/fd16273ade4b/moksha-nov6-rehearsal-c489885/native-review/empty-resources
CAPTURES=/workspace/scratch/fd16273ade4b/moksha-nov6-rehearsal-c489885/native-review/captures
if [ -n "$(ls -A "$EMPTY")" ]; then echo "Native resource directory is not empty." >&2; exit 1; fi
if [ -n "$(ls -A "$CAPTURES")" ]; then echo "Capture files already exist. Preserve them and choose a new capture directory." >&2; exit 1; fi
cd "$EMPTY"
exec /opt/godot/4.6.3/Godot_v4.6.3-stable_linux.x86_64 --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --disable-vsync --path /workspace/scratch/fd16273ade4b/moksha-nov6-rehearsal-c489885/native-review/empty-resources --main-pack /workspace/scratch/fd16273ade4b/moksha-nov6-rehearsal-c489885/MOKSHA.pck --script /workspace/scratch/fd16273ade4b/moksha-nov6-rehearsal-c489885/native-review/native_review_wrapper.gd -- --capture-ui --output=/workspace/scratch/fd16273ade4b/moksha-nov6-rehearsal-c489885/native-review/captures
