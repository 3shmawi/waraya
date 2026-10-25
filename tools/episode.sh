#!/bin/sh
# One devlog episode filmed in the lab (tool/lab_film.dart), with the game's
# own sound under it (tool/promo/sound.py), to docs/media/devlog/<slug>.mp4.
#
#   tools/episode.sh 1
set -eu
n=${1:?which episode}
repo=$(cd "$(dirname "$0")/.." && pwd)
work=${WARAYA_FILM_WORK:-${TMPDIR:-/tmp}/waraya-film}
cd "$repo"
WARAYA_EPISODE=$n WARAYA_FILM_OUT="$work" flutter test tool/lab_film.dart >/dev/null
dir=$(ls -dt "$work"/lab-"$n"-*/ | head -1)
slug=$(basename "$dir")
python3 tool/promo/sound.py "$dir" "$work/$slug.wav"
mkdir -p docs/media/devlog
ffmpeg -y -loglevel error -framerate 30 -i "$dir/%05d.png" -i "$work/$slug.wav" \
  -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p \
  -c:a aac -b:a 128k -shortest -movflags +faststart "docs/media/devlog/$slug.mp4"
ls -la "docs/media/devlog/$slug.mp4"
