#!/usr/bin/env sh

# Strict shell mode.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_ROOT=${BUILD_ROOT:-"$ROOT/build"}
ROCKSPEC="$ROOT/tty-scm-1.rockspec"

run_for() {
  interp=$1
  lua_version=$2

  if ! command -v "$interp" >/dev/null 2>&1; then
    printf 'skip %s: interpreter not found\n' "$interp"
    return 0
  fi

  out_dir="$BUILD_ROOT/$interp"
  mkdir -p "$out_dir"

  printf 'build %s with luarocks\n' "$interp"
  luarocks --tree "$out_dir" --lua-version="$lua_version" make "$ROCKSPEC"

  printf 'test %s\n' "$interp"
  (
    eval "$(luarocks --tree "$out_dir" --lua-version="$lua_version" path --no-bin)"
    busted --lua="$interp"
  )
}

run_for luajit 5.1
run_for lua5.1 5.1
run_for lua5.2 5.2
run_for lua5.3 5.3
run_for lua5.4 5.4
run_for lua5.5 5.5
