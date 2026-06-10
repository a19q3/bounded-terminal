#!/bin/sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

fail() {
    printf >&2 'verify-doc-pins: %s\n' "$1"
    exit 1
}

pinned_rev() {
    name=$1
    sed -n "s/^${name}_REV=\${${name}_REV:-\([0-9a-f][0-9a-f]*\)}$/\1/p" "$ROOT_DIR/install.sh"
}

readme_rev() {
    tool=$1
    sed -n "s|^cargo install --git https://github.com/a19q3/${tool}\\.git --rev \\([0-9a-f][0-9a-f]*\\)$|\\1|p" "$ROOT_DIR/README.md"
}

check_tool() {
    tool=$1
    var=$2

    expected=$(pinned_rev "$var")
    [ -n "$expected" ] || fail "missing install.sh pin for $var"

    actual=$(readme_rev "$tool")
    [ -n "$actual" ] || fail "missing README quick-start pin for $tool"

    if [ "$actual" != "$expected" ]; then
        fail "$tool README pin mismatch: README has $actual but install.sh has $expected"
    fi

    printf '%s README pin ok: %s\n' "$tool" "$actual"
}

check_tool cap CAP
check_tool span SPAN
check_tool fx FX
check_tool tap TAP

printf 'README quick-start pins match install.sh\n'
