#!/bin/bash
# Runs at the start of every session. Two jobs.
#
# One: say what the other branches are carrying. A session starts on one
# branch and nothing tells it the rest exist, which is how two of them wrote
# the end-of-campaign screen and the fade between levels from the same
# starting point, on two branches, and a day of work went in the bin.
#
# Two: put the pinned Flutter SDK and this project's packages in place, so a
# session can run `flutter analyze` and `flutter test` instead of spending its
# first ten minutes installing a toolchain — or, worse, shipping a change it
# never ran anything against.
#
# It says nothing at all when there is nothing to say.
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

# ---------------------------------------------------------------- branches --

report_branches() {
  command -v git >/dev/null 2>&1 || return 0
  git rev-parse --git-dir >/dev/null 2>&1 || return 0

  # Without this the session only knows the branches that happened to be
  # cloned with it, which on a fresh container is one.
  git fetch --all --prune --quiet 2>/dev/null || return 0

  local ahead="" branches branch count base subject
  branches=$(git for-each-ref --sort=-committerdate \
    --format='%(refname:short)' refs/remotes/origin 2>/dev/null |
    grep -v '^origin/HEAD$')

  while IFS= read -r branch; do
    [ -z "$branch" ] && continue
    count=$(git rev-list --count "HEAD..$branch" 2>/dev/null) || continue
    [ "${count:-0}" -eq 0 ] && continue
    # Commits we have not got, but no files we have not got: the merge commit
    # of work already in this checkout. Counting that as something to go and
    # look at would make this print on every session, which is how a warning
    # stops being read.
    base=$(git merge-base HEAD "$branch" 2>/dev/null) || continue
    git diff --quiet "$base" "$branch" 2>/dev/null && continue
    subject=$(git log -1 --format='%cs  %s' "$branch" 2>/dev/null)
    ahead="${ahead}  ${branch}  (+${count})  ${subject}
"
  done <<EOB
$branches
EOB

  [ -z "$ahead" ] && return 0

  cat <<EOM
Other branches carry work this checkout has not got:

${ahead}
Before starting anything, check whether what you are about to build is
already on one of them (git log --oneline HEAD..<branch>). If it is, branch
off that one and continue it — do not rebuild it from the default branch.
See the note at the top of CLAUDE.md.

EOM
}

# ----------------------------------------------------------------- flutter --

# The version this project is pinned to. `.fvmrc` is the single copy of that
# number — the CI workflow fails the build if its own copy drifts from it —
# so it is read here rather than written down a third time.
pinned_flutter() {
  [ -f .fvmrc ] || return 1
  python3 -c 'import json; print(json.load(open(".fvmrc"))["flutter"])' \
    2>/dev/null && return 0
  sed -n 's/.*"flutter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .fvmrc
}

install_flutter() {
  local pin sdk url tmp
  pin=$(pinned_flutter) || return 0
  [ -z "$pin" ] && return 0
  sdk="$HOME/flutter"

  # The marker is written last, so an install that died halfway is not
  # mistaken for one that finished.
  if [ "$(cat "$sdk/.waraya-version" 2>/dev/null)" != "$pin" ]; then
    echo "waraya: installing Flutter $pin (a few minutes, once per container)" >&2
    rm -rf "$sdk"
    tmp=$(mktemp -d) || return 0
    url="https://storage.googleapis.com/flutter_infra_release/releases/stable"
    url="$url/linux/flutter_linux_${pin}-stable.tar.xz"
    if ! curl -fsSL --retry 3 -o "$tmp/flutter.tar.xz" "$url" >&2 ||
      ! tar -xf "$tmp/flutter.tar.xz" -C "$tmp" >&2 ||
      ! mv "$tmp/flutter" "$sdk"; then
      rm -rf "$tmp"
      echo "Flutter $pin could not be installed, so flutter and dart are not"
      echo "on PATH in this session: analyze and test cannot be run here, and"
      echo "a change made now is a change only CI has ever run."
      echo
      return 0
    fi
    rm -rf "$tmp"
    printf '%s\n' "$pin" >"$sdk/.waraya-version"
  fi

  # Every flutter command shells out to git inside the SDK's own checkout, and
  # the unpacked tree is not owned by the user running it.
  git config --global --add safe.directory "$sdk" 2>/dev/null

  export PATH="$sdk/bin:$PATH"
  export FLUTTER_ROOT="$sdk"
  export FLUTTER_SUPPRESS_ANALYTICS=true
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    {
      echo "export PATH=\"$sdk/bin:\$PATH\""
      echo "export FLUTTER_ROOT=\"$sdk\""
      echo "export FLUTTER_SUPPRESS_ANALYTICS=true"
    } >>"$CLAUDE_ENV_FILE"
  fi

  if flutter --suppress-analytics pub get >&2; then
    cat <<EOM
Flutter $pin is on PATH and this project's packages are fetched.

  flutter analyze
  flutter test
  flutter test test/level/levels_test.dart
  flutter build web -t lib/main_levels.dart --no-web-resources-cdn

Run them before pushing: every level ships a recorded solution and a recorded
wrong idea, and those tests are the only thing that says a change to a number
did not quietly unsolve a puzzle.

EOM
  else
    cat <<EOM
Flutter $pin is on PATH, but `flutter pub get` failed. Run it and read the
error before trusting anything a test says.

EOM
  fi
}

report_branches
# Linux only, and the person's own machine has its own SDK through FVM.
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] && install_flutter
exit 0
