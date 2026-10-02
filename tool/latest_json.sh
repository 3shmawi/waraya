#!/usr/bin/env bash
# Writes latest.json — what the game's update card reads (lib/update/).
#
#   tool/latest_json.sh OUT [--build SHA] [--build-number N]
#
# version       from pubspec.yaml
# build         the commit the web game was built from (pages.yml), or empty
# buildNumber   the release's build number (release.yml), or 0
# notes         fastlane/release_notes/{ar,en}.txt when they were edited
#               since the last release; otherwise written from the commits
#               since then, so a release never goes out saying nothing — or
#               saying the last release's news again
# changes       the last 30 commits, newest first, {sha, subject}: the web
#               game shows the ones newer than the build it is running
#
# Needs the history (actions/checkout with fetch-depth: 0) and jq.
set -euo pipefail

out=$1; shift
build=""
number=0
while [ $# -gt 0 ]; do
  case "$1" in
    --build) build=$2; shift 2 ;;
    --build-number) number=$2; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

version=$(sed -nE 's/^version: *([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' pubspec.yaml)
[ -n "$version" ] || { echo "no version in pubspec.yaml" >&2; exit 1; }

# The release before this commit: the newest v* tag that is not on HEAD.
previous=$(git tag --list 'v*' --sort=-v:refname --no-contains HEAD | head -n1 || true)
range=${previous:+$previous..}HEAD

# What a player is told: the subjects of the commits, minus the
# bookkeeping. Commit subjects are written for whoever reads the history;
# they are the honest automatic answer to "what changed".
players_lines() {
  git log --no-merges --format='%s' "$range" \
    | grep -vE '^(Version [0-9]|Merge )' \
    | head -n 6 \
    | sed 's/^/• /'
}

if [ -n "$previous" ] && git diff --quiet "$previous" HEAD -- fastlane/release_notes; then
  auto=$(players_lines)
  ar=$auto
  en=$auto
  from="the commits since $previous"
else
  from="fastlane/release_notes"
  ar=$(cat fastlane/release_notes/ar.txt)
  en=$(cat fastlane/release_notes/en.txt)
fi

changes=$(git log --no-merges -n 30 --format='%H%x09%s' \
  | grep -vP '\tVersion [0-9]' \
  | jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {sha: .[0], subject: .[1]})')

jq -n \
  --arg version "$version" \
  --arg build "$build" \
  --argjson buildNumber "$number" \
  --arg ar "$ar" \
  --arg en "$en" \
  --argjson changes "$changes" \
  '{version: $version, build: $build, buildNumber: $buildNumber,
    notes: {ar: $ar, en: $en}, changes: $changes}' > "$out"

jq -e '.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")' "$out" > /dev/null
echo "wrote $out: $version, build ${build:-none}, #$number, notes from $from"
