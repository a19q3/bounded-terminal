#!/bin/sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PARENT_DIR=$(cd "$ROOT_DIR/.." && pwd)

fail() {
    printf >&2 'verify-pins: %s\n' "$1"
    exit 1
}

pinned_rev() {
    name=$1
    sed -n "s/^${name}_REV=\${${name}_REV:-\([0-9a-f][0-9a-f]*\)}$/\1/p" "$ROOT_DIR/install.sh"
}

check_tool() {
    tool=$1
    var=$2
    repo="$PARENT_DIR/$tool"

    [ -d "$repo/.git" ] || fail "missing Git repo: $repo"

    expected=$(pinned_rev "$var")
    [ -n "$expected" ] || fail "missing pinned revision for $var"

    if [ "${VERIFY_PINS_FETCH:-1}" = "1" ]; then
        git -C "$repo" fetch --quiet origin main || fail "$tool fetch failed"
    else
        printf '%s fetch skipped because VERIFY_PINS_FETCH=0\n' "$tool"
    fi

    actual=$(git -C "$repo" rev-parse HEAD)
    if [ "$actual" != "$expected" ]; then
        fail "$tool pin mismatch: install.sh has $expected but local HEAD is $actual"
    fi

    status=$(git -C "$repo" status -sb)
    case "$status" in
        *ahead*|*behind*|*'??'*|*' M '*|*'M  '*|*' A '*|*'A  '*|*' D '*|*'D  '*)
            fail "$tool is not clean and synced: $status"
            ;;
    esac

    printf '%s pin ok: %s\n' "$tool" "$actual"
}

check_tool cap CAP
check_tool span SPAN
check_tool fx FX
check_tool tap TAP

printf 'all pinned tool revisions match clean synced sibling repos\n'
