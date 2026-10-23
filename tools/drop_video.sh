#!/bin/sh
# One weekly drop's TikTok video (docs/media/drops.md): the level that
# teaches the new thing, a harder one as the teaser, and the card that says
# what it is and the QR code to get the game (nothing about next Friday).
#
#   tools/drop_video.sh mirror          # Arabic
#   tools/drop_video.sh mirror en       # English card
#
# Every frame comes out of the game: the footage is tool/clips.dart playing
# each level's own recorded solution, the card is tool/drop_card.dart. So the
# video cannot show a solution the game no longer accepts, and two runs make
# the same file. 1080x1920, 30 fps, silent — the sound goes on in the app.
#
# Writes docs/media/drops/<drop>[-en].mp4. Needs ffmpeg.
set -eu

drop=${1:?which drop: mirror, dog, stairwell, basket}
lang=${2:-ar}

# The clips each drop shows, by number in tool/clips.dart, in order.
case "$drop" in
  mirror) clips="16 17" ;;
  dog) clips="18 19" ;;
  stairwell) clips="20 21" ;;
  basket) clips="22 23" ;;
  *) echo "no drop called $drop" >&2; exit 1 ;;
esac

repo=$(cd "$(dirname "$0")/.." && pwd)
work=${WARAYA_DROP_WORK:-${TMPDIR:-/tmp}/waraya-drop-$drop}
mkdir -p "$work/clips" "$repo/docs/media/drops"
cd "$repo"

# Half a second of cross-fade between the pieces: long enough to read as a
# cut on purpose, short enough not to eat the moment a level is finished.
fade=0.5

segments=""
for n in $clips; do
  echo "rendering clip $n"
  WARAYA_CLIP=$n WARAYA_CLIP_EVERY=2 WARAYA_CLIP_OUT="$work/clips" \
    flutter test tool/clips.dart >/dev/null
  dir=$(ls -d "$work/clips/$(printf %02d "$n")"-*/ | head -1)
  ffmpeg -y -loglevel error -framerate 30 -i "$dir/%05d.png" \
    -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p "$work/clip-$n.mp4"
  segments="$segments $work/clip-$n.mp4"
done

echo "rendering the card"
WARAYA_DROP=$drop WARAYA_DROP_LANG=$lang WARAYA_DROP_OUT="$work" \
  flutter test tool/drop_card.dart >/dev/null
ffmpeg -y -loglevel error -framerate 30 -i "$work/card/%04d.png" \
  -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p "$work/card.mp4"
segments="$segments $work/card.mp4"

# Chain the pieces with xfade: each fade starts where the video so far ends,
# less the fade.
inputs=""
filter=""
offset=0
i=0
prev="0:v"
for seg in $segments; do
  inputs="$inputs -i $seg"
  length=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$seg")
  if [ "$i" -gt 0 ]; then
    offset=$(echo "$offset - $fade" | bc -l)
    filter="$filter[$prev][$i:v]xfade=transition=fade:duration=$fade:offset=$offset[v$i];"
    prev="v$i"
  fi
  offset=$(echo "$offset + $length" | bc -l)
  i=$((i + 1))
done

suffix=""
[ "$lang" = en ] && suffix="-en"
out="$repo/docs/media/drops/$drop$suffix.mp4"
# shellcheck disable=SC2086
ffmpeg -y -loglevel error $inputs -filter_complex "${filter%;}" -map "[$prev]" \
  -c:v libx264 -preset slow -crf 21 -pix_fmt yuv420p -movflags +faststart "$out"
ls -la "$out"
