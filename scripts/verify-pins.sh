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

    if [ "${VERIFY_PINS_FETCH:-1}" = "1" ]; then
        remote_head=$(git -C "$repo" rev-parse refs/remotes/origin/main)
        if [ "$actual" != "$remote_head" ]; then
            fail "$tool is not synced with origin/main: local HEAD is $actual but origin/main is $remote_head"
        fi
    fi

    branch_status=$(git -C "$repo" status -sb)
    case "$branch_status" in
        *ahead*|*behind*|*gone*)
            fail "$tool is not clean and synced: $branch_status"
            ;;
    esac

    dirty_status=$(git -C "$repo" status --porcelain=v1)
    if [ -n "$dirty_status" ]; then
        fail "$tool is not clean and synced: $branch_status
$dirty_status"
    fi

    printf '%s pin ok: %s\n' "$tool" "$actual"
}

check_tool cap CAP
check_tool span SPAN
check_tool fx FX
check_tool tap TAP

printf 'all pinned tool revisions match clean synced sibling repos\n'
