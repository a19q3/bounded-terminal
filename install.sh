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

CAP_REV=${CAP_REV:-42a4cd43ceeeef8d5fed804445ebe62134687f2d}
SPAN_REV=${SPAN_REV:-49b820213bce1fe488d6691f3891bdcc697ee8b3}
FX_REV=${FX_REV:-b2d63b4c77d8e8c425b2387f7aa3c4657342594b}
TAP_REV=${TAP_REV:-b7b3c88049d85b22f91e152b61843c10b2cce944}

install_tool cap https://github.com/a19q3/cap.git "$CAP_REV"
install_tool span https://github.com/a19q3/span.git "$SPAN_REV"
install_tool fx https://github.com/a19q3/fx.git "$FX_REV"
install_tool tap https://github.com/a19q3/tap.git "$TAP_REV"

printf 'bounded-terminal tools installed\n'
