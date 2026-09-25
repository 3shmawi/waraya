#!/bin/bash
# Runs at the start of every session, and exists for exactly one failure:
# a session that starts on the default branch, cannot see the branch another
# session is working on, and quietly builds the same thing a second time.
# That has happened here — two sessions wrote the end-of-campaign screen and
# the fade between levels, on two branches, from the same starting point.
#
# It says nothing at all when there is nothing to say.
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Without this the session only knows the branches that happened to be cloned
# with it, which on a fresh container is one.
git fetch --all --prune --quiet 2>/dev/null || exit 0

ahead=""
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

[ -z "$ahead" ] && exit 0

cat <<EOM
Other branches carry work this checkout has not got:

${ahead}
Before starting anything, check whether what you are about to build is
already on one of them (git log --oneline HEAD..<branch>). If it is, branch
off that one and continue it — do not rebuild it from the default branch.
See the note at the top of CLAUDE.md.
EOM
