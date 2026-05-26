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
    printf '==> installing %s from %s\n' "$name" "$repo"
    cargo install --git "$repo" --force
}

require cargo

install_tool cap https://github.com/a19q3/cap.git
install_tool span https://github.com/a19q3/span.git
install_tool fx https://github.com/a19q3/fx.git
install_tool tap https://github.com/a19q3/tap.git

printf 'bounded-terminal tools installed\n'

