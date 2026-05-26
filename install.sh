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

CAP_REV=${CAP_REV:-95e6410d28079d749c1660e0bbc41b14acd69430}
SPAN_REV=${SPAN_REV:-3df186cd3d7fcc9254cbd4f958ab8537554dfdb5}
FX_REV=${FX_REV:-b173721bd8ad0a77f0c6404e9bdc9a0d57e683ff}
TAP_REV=${TAP_REV:-04d40f351b206bb48d23dd72fd3525ce24894f5a}

install_tool cap https://github.com/a19q3/cap.git "$CAP_REV"
install_tool span https://github.com/a19q3/span.git "$SPAN_REV"
install_tool fx https://github.com/a19q3/fx.git "$FX_REV"
install_tool tap https://github.com/a19q3/tap.git "$TAP_REV"

printf 'bounded-terminal tools installed\n'
