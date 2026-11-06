#!/bin/sh
set -eu
export HOME=/workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-b2e7f35/home
export XDG_DATA_HOME=/workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-b2e7f35/data
export XDG_CONFIG_HOME=/workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-b2e7f35/config
export XDG_CACHE_HOME=/workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-b2e7f35/cache
cd /workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-b2e7f35/empty-resources
exec /opt/godot/4.6.3/Godot_v4.6.3-stable_linux.x86_64 --display-driver x11 --audio-driver Dummy --disable-vsync --rendering-method gl_compatibility --path /workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-b2e7f35/empty-resources --main-pack /workspace/scratch/fd16273ade4b/moksha-nov6-rehearsal-b2e7f35/MOKSHA.pck > /workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-b2e7f35/native.log 2>&1
