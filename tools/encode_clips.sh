#!/bin/sh
# Turns each folder of PNG frames written by tool/clips.dart into one mp4.
#
#   flutter test tool/clips.dart
#   tools/encode_clips.sh [frames-dir]
#
# yuv420p and a plain h264 profile because that is what the phone apps will
# accept without re-encoding it themselves into something worse.
set -eu

root=${1:-${WARAYA_CLIP_OUT:-${TMPDIR:-/tmp}/waraya-clips}}
[ -d "$root" ] || { echo "no frames in $root" >&2; exit 1; }

for dir in "$root"/*/; do
  name=$(basename "$dir")
  [ -f "$dir/00000.png" ] || continue
  echo "encoding $name"
  ffmpeg -y -loglevel error -framerate 60 -i "$dir/%05d.png" \
    -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p \
    -movflags +faststart "$root/$name.mp4"
done

ls -la "$root"/*.mp4
