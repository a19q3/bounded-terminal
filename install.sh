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

CAP_REV=${CAP_REV:-485f8c35693f661e6dba68c1dd7cad223b7fedd1}
SPAN_REV=${SPAN_REV:-6b5d775b6a6d18c883d162ee295b4b91e359dff0}
FX_REV=${FX_REV:-99a293c3b7594db745e61559eb4d462618829046}
TAP_REV=${TAP_REV:-7c2e7c8b3db9aa3ef204d3ad1aa01a881de5f242}

install_tool cap https://github.com/a19q3/cap.git "$CAP_REV"
install_tool span https://github.com/a19q3/span.git "$SPAN_REV"
install_tool fx https://github.com/a19q3/fx.git "$FX_REV"
install_tool tap https://github.com/a19q3/tap.git "$TAP_REV"

printf 'bounded-terminal tools installed\n'
