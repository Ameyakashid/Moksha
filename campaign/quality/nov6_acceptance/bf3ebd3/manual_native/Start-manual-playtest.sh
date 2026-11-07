#!/bin/sh
set -eu
export HOME=/workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-bf3ebd3/home
export XDG_DATA_HOME=/workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-bf3ebd3/data
export XDG_CONFIG_HOME=/workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-bf3ebd3/config
export XDG_CACHE_HOME=/workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-bf3ebd3/cache
cd /workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-bf3ebd3/empty-resources
/opt/godot/4.6.3/Godot_v4.6.3-stable_linux.x86_64 --verbose --display-driver x11 --audio-driver Dummy --disable-vsync --rendering-method gl_compatibility --path /workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-bf3ebd3/empty-resources --main-pack /workspace/scratch/fd16273ade4b/moksha-nov6-rehearsal-c489885/MOKSHA.pck > /workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-bf3ebd3/native.log 2>&1
printf "EXIT_CODE=0\n" >> /workspace/scratch/fd16273ade4b/moksha-nov6-packed-manual-bf3ebd3/native.log
