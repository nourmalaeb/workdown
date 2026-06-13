#!/usr/bin/env bats
# wrkdwn test suite — run with: bats test/
#
# Requires bats >= 1.5. Install: https://github.com/bats-core/bats-core

export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
export GIT_TERMINAL_PROMPT=0

setup() {
  export GIT_AUTHOR_NAME="Test User"
  export GIT_AUTHOR_EMAIL="test@example.com"
  export GIT_COMMITTER_NAME="Test User"
  export GIT_COMMITTER_EMAIL="test@example.com"
  TEST_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

# Create a bare remote repo with main as the default branch; echo its path.
bare_repo() {
  local path="$TEST_DIR/${1}.git"
  git init --bare -q --initial-branch=main "$path"
  echo "$path"
}

# Clone a bare repo, add an initial empty commit, push; echo the clone dir.
clone_with_commit() {
  local remote="$1" name="${2:-code}"
  local dir="$TEST_DIR/$name"
  git clone -q "$remote" "$dir" 2>/dev/null
  git -C "$dir" commit --allow-empty -q -m "init"
  git -C "$dir" push -q
  echo "$dir"
}

# Run wrkdwn init inside $dir against the given workdown remote.
do_init() {
  local dir="$1" wd_remote="$2"
  (cd "$dir" && wrkdwn init "$wd_remote") >/dev/null 2>&1
}

# --------------------------------------------------------------------------
# 1. Clone derivation
# --------------------------------------------------------------------------

@test "clone derivation: init derives -workdown suffix from origin URL" {
  local pub wd dir
  pub="$(bare_repo project)"
  wd="$(bare_repo project-workdown)"
  dir="$(clone_with_commit "$pub")"

  run bash -c "cd \"$dir\" && wrkdwn init 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"assuming: $wd"* ]]
}

@test "clone derivation: .git suffix is preserved, not doubled" {
  local pub wd dir
  pub="$(bare_repo project)"
  wd="$(bare_repo project-workdown)"
  dir="$(clone_with_commit "$pub")"

  run bash -c "cd \"$dir\" && wrkdwn init 2>&1"
  [ "$status" -eq 0 ]
  # Should end in project-workdown.git, not project.git-workdown or project.git-workdown.git
  [[ "$output" == *"project-workdown.git"* ]]
  [[ "$output" != *"project.git-workdown"* ]]
}

# --------------------------------------------------------------------------
# 2. Subdir roundtrip
# --------------------------------------------------------------------------

@test "subdir roundtrip: wrkdwn status works from a subdirectory" {
  local pub wd dir
  pub="$(bare_repo project)"
  wd="$(bare_repo project-workdown)"
  dir="$(clone_with_commit "$pub")"
  do_init "$dir" "$wd"

  mkdir -p "$dir/src/feature"

  run bash -c "cd \"$dir/src/feature\" && wrkdwn status 2>&1"
  [ "$status" -eq 0 ]
}

@test "subdir roundtrip: wrkdwn add works for a .wrk.md created in a subdir" {
  local pub wd dir
  pub="$(bare_repo project)"
  wd="$(bare_repo project-workdown)"
  dir="$(clone_with_commit "$pub")"
  do_init "$dir" "$wd"

  mkdir -p "$dir/src"
  echo "# Feature doc" > "$dir/src/feature.wrk.md"

  # From inside src/, the CWD-relative path is just the filename
  run bash -c "cd \"$dir/src\" && wrkdwn add feature.wrk.md 2>&1"
  [ "$status" -eq 0 ]

  run bash -c "cd \"$dir\" && wrkdwn status --short 2>&1"
  [[ "$output" == *"feature.wrk.md"* ]]
}

# --------------------------------------------------------------------------
# 3. add-dot safety
# --------------------------------------------------------------------------

@test "add-dot safety: wrkdwn add . stages .wrk.md files" {
  local pub wd dir
  pub="$(bare_repo project)"
  wd="$(bare_repo project-workdown)"
  dir="$(clone_with_commit "$pub")"
  do_init "$dir" "$wd"

  echo "# Notes" > "$dir/notes.wrk.md"
  echo "public code" > "$dir/README.md"

  run bash -c "cd \"$dir\" && wrkdwn add . 2>&1"
  [ "$status" -eq 0 ]

  run bash -c "cd \"$dir\" && wrkdwn status --short 2>&1"
  [[ "$output" == *"notes.wrk.md"* ]]
}

@test "add-dot safety: wrkdwn add . does not stage non-.wrk.md files" {
  local pub wd dir
  pub="$(bare_repo project)"
  wd="$(bare_repo project-workdown)"
  dir="$(clone_with_commit "$pub")"
  do_init "$dir" "$wd"

  echo "# Notes" > "$dir/notes.wrk.md"
  echo "public code" > "$dir/README.md"

  (cd "$dir" && wrkdwn add .) >/dev/null 2>&1

  run bash -c "cd \"$dir\" && wrkdwn status --short 2>&1"
  [[ "$output" != *"README.md"* ]]
}

# --------------------------------------------------------------------------
# 4. Clean guard
# --------------------------------------------------------------------------

@test "clean guard: wrkdwn clean exits non-zero" {
  run bash -c "wrkdwn clean 2>&1"
  [ "$status" -ne 0 ]
}

@test "clean guard: wrkdwn clean prints an informative error" {
  run bash -c "wrkdwn clean 2>&1"
  [[ "$output" == *"disabled"* ]]
}

# --------------------------------------------------------------------------
# 5. Leak guard
# --------------------------------------------------------------------------

@test "leak guard: pre-push hook blocks a .wrk.md commit from reaching the public repo" {
  local pub wd dir
  pub="$(bare_repo project)"
  wd="$(bare_repo project-workdown)"
  dir="$(clone_with_commit "$pub")"
  do_init "$dir" "$wd"

  # Force a .wrk.md into the public repo (bypasses wrkdwn protections)
  echo "leaked" > "$dir/secret.wrk.md"
  git -C "$dir" add -f "$dir/secret.wrk.md"
  git -C "$dir" commit -q -m "accidental leak"

  run bash -c "cd \"$dir\" && git push 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"BLOCKED"* ]]
}

@test "leak guard: pre-push hook allows a clean push (no .wrk.md in public commits)" {
  local pub wd dir
  pub="$(bare_repo project)"
  wd="$(bare_repo project-workdown)"
  dir="$(clone_with_commit "$pub")"
  do_init "$dir" "$wd"

  echo "public code" > "$dir/app.sh"
  git -C "$dir" add "$dir/app.sh"
  git -C "$dir" commit -q -m "add app"

  run bash -c "cd \"$dir\" && git push 2>&1"
  [ "$status" -eq 0 ]
}

# --------------------------------------------------------------------------
# 6. Idempotent init
# --------------------------------------------------------------------------

@test "idempotent init: running init twice does not duplicate public exclude entries" {
  local pub wd dir
  pub="$(bare_repo project)"
  wd="$(bare_repo project-workdown)"
  dir="$(clone_with_commit "$pub")"

  do_init "$dir" "$wd"
  do_init "$dir" "$wd"

  local excl="$dir/.git/info/exclude"
  [ "$(grep -c '^\*\.wrk\.md$' "$excl")" -eq 1 ]
  [ "$(grep -c '^\.workdown\.git/$' "$excl")" -eq 1 ]
  [ "$(grep -c '^\.ignore$' "$excl")" -eq 1 ]
}

@test "idempotent init: running init twice does not duplicate workdown exclude entries" {
  local pub wd dir
  pub="$(bare_repo project)"
  wd="$(bare_repo project-workdown)"
  dir="$(clone_with_commit "$pub")"

  do_init "$dir" "$wd"
  do_init "$dir" "$wd"

  local wd_excl="$dir/.workdown.git/info/exclude"
  # The block is *\n!*/\n!*.wrk.md — check each line appears exactly once
  [ "$(grep -cxF '*'          "$wd_excl")" -eq 1 ]
  [ "$(grep -cxF '!*/'        "$wd_excl")" -eq 1 ]
  [ "$(grep -cxF '!*.wrk.md' "$wd_excl")" -eq 1 ]
}

@test "idempotent init: running init twice does not duplicate .ignore entries" {
  local pub wd dir
  pub="$(bare_repo project)"
  wd="$(bare_repo project-workdown)"
  dir="$(clone_with_commit "$pub")"

  do_init "$dir" "$wd"
  do_init "$dir" "$wd"

  [ "$(grep -cxF '!*.wrk.md' "$dir/.ignore")" -eq 1 ]
}

# --------------------------------------------------------------------------
# 7. Fresh-teammate bootstrap
# --------------------------------------------------------------------------

@test "fresh-teammate bootstrap: new clone materializes existing workdown docs after setup" {
  local pub wd dev1 dev2
  pub="$(bare_repo project)"
  wd="$(bare_repo project-workdown)"
  dev1="$(clone_with_commit "$pub")"
  do_init "$dev1" "$wd"

  # Dev1 creates a doc and pushes it to the workdown remote
  echo "# Team notes" > "$dev1/notes.wrk.md"
  (cd "$dev1" && wrkdwn add notes.wrk.md) >/dev/null 2>&1
  (cd "$dev1" && wrkdwn commit -q -m "add notes") >/dev/null 2>&1
  (cd "$dev1" && wrkdwn push origin main -q) >/dev/null 2>&1

  # Dev2 clones fresh and runs setup
  dev2="$TEST_DIR/dev2"
  git clone -q "$pub" "$dev2" 2>/dev/null
  (cd "$dev2" && wrkdwn init "$wd") >/dev/null 2>&1

  # The workdown doc should have materialized
  [ -f "$dev2/notes.wrk.md" ]
  run cat "$dev2/notes.wrk.md"
  [[ "$output" == *"Team notes"* ]]
}

@test "fresh-teammate bootstrap: new clone does NOT get workdown docs in its public git index" {
  local pub wd dev1 dev2
  pub="$(bare_repo project)"
  wd="$(bare_repo project-workdown)"
  dev1="$(clone_with_commit "$pub")"
  do_init "$dev1" "$wd"

  echo "# Secret doc" > "$dev1/secret.wrk.md"
  (cd "$dev1" && wrkdwn add secret.wrk.md) >/dev/null 2>&1
  (cd "$dev1" && wrkdwn commit -q -m "add secret doc") >/dev/null 2>&1
  (cd "$dev1" && wrkdwn push origin main -q) >/dev/null 2>&1

  dev2="$TEST_DIR/dev2"
  git clone -q "$pub" "$dev2" 2>/dev/null
  (cd "$dev2" && wrkdwn init "$wd") >/dev/null 2>&1

  # The file should NOT appear in the public git index
  run git -C "$dev2" ls-files secret.wrk.md
  [ "$output" = "" ]
}

# --------------------------------------------------------------------------
# 8. Local-only init
# --------------------------------------------------------------------------

@test "local init: wrkdwn init --local succeeds without any remote" {
  local pub dir
  pub="$(bare_repo project)"
  dir="$(clone_with_commit "$pub")"

  run bash -c "cd \"$dir\" && wrkdwn init --local 2>&1"
  [ "$status" -eq 0 ]
  [ -d "$dir/.workdown.git" ]
}

@test "local init: add and commit work after --local init (no remote needed)" {
  local pub dir
  pub="$(bare_repo project)"
  dir="$(clone_with_commit "$pub")"
  (cd "$dir" && wrkdwn init --local) >/dev/null 2>&1

  echo "# Notes" > "$dir/notes.wrk.md"
  run bash -c "cd \"$dir\" && wrkdwn add notes.wrk.md && wrkdwn commit -m 'add notes' 2>&1"
  [ "$status" -eq 0 ]

  run bash -c "cd \"$dir\" && wrkdwn log --oneline 2>&1"
  [[ "$output" == *"add notes"* ]]
}

@test "local init: --local and a URL are mutually exclusive" {
  local pub dir
  pub="$(bare_repo project)"
  dir="$(clone_with_commit "$pub")"

  run bash -c "cd \"$dir\" && wrkdwn init --local https://example.com/repo-workdown 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"mutually exclusive"* ]]
}
