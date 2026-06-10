#!/bin/sh
set -eu

require() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf >&2 'required command not found: %s\n' "$1"
        exit 1
    fi
}

install_tool() {
    name=$1
    repo=$2
    rev=$3
    printf '==> installing %s from %s at %s\n' "$name" "$repo" "$rev"
    cargo install --git "$repo" --rev "$rev" --force
}

require cargo

CAP_REV=${CAP_REV:-2be5acff6ff01b70b47adb7527e914e8547633ff}
SPAN_REV=${SPAN_REV:-9e454d5be29c2d657decee28901872fff016650d}
FX_REV=${FX_REV:-85ac8663e0edb174c1fb6ece2cd9f20635e75766}
TAP_REV=${TAP_REV:-e6f7db29c0ac32812c0e7c95f8d17bf951172a3a}

install_tool cap https://github.com/a19q3/cap.git "$CAP_REV"
install_tool span https://github.com/a19q3/span.git "$SPAN_REV"
install_tool fx https://github.com/a19q3/fx.git "$FX_REV"
install_tool tap https://github.com/a19q3/tap.git "$TAP_REV"

printf 'bounded-terminal tools installed\n'
