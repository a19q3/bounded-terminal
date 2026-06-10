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

CAP_REV=${CAP_REV:-b5d87b9e3d178aaf2122f61836c0c5e3f0c26f9b}
SPAN_REV=${SPAN_REV:-9e454d5be29c2d657decee28901872fff016650d}
FX_REV=${FX_REV:-85ac8663e0edb174c1fb6ece2cd9f20635e75766}
TAP_REV=${TAP_REV:-4eb045e40c2cbad8f98509cb5abee6247a3afc5c}

install_tool cap https://github.com/a19q3/cap.git "$CAP_REV"
install_tool span https://github.com/a19q3/span.git "$SPAN_REV"
install_tool fx https://github.com/a19q3/fx.git "$FX_REV"
install_tool tap https://github.com/a19q3/tap.git "$TAP_REV"

printf 'bounded-terminal tools installed\n'
