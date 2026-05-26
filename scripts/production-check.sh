#!/bin/sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PARENT_DIR=$(cd "$ROOT_DIR/.." && pwd)
TOOLS="cap fx span tap"

fail() {
    printf >&2 'production-check: %s\n' "$1"
    exit 1
}

require() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fail "required command not found: $1"
    fi
}

check_tool() {
    tool=$1
    repo="$PARENT_DIR/$tool"

    [ -d "$repo" ] || fail "missing sibling repo: $repo"
    printf '==> checking %s\n' "$tool"
    (
        cd "$repo"
        cargo fmt --check
        cargo clippy -- -D warnings
        cargo test
        git diff --check
    )
}

main() {
    require cargo
    require git
    require sh

    for tool in $TOOLS; do
        check_tool "$tool"
    done

    sh -n "$ROOT_DIR/install.sh"
    sh -n "$ROOT_DIR/scripts/self-host-check.sh"
    sh "$ROOT_DIR/scripts/self-host-check.sh"

    printf 'production check passed\n'
}

main "$@"
