#!/bin/sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PARENT_DIR=$(cd "$ROOT_DIR/.." && pwd)
BIN_DIR="$ROOT_DIR/.self-host/bin"
REPORT_DIR="$ROOT_DIR/reports/self-host"
REPORT_FILE="$REPORT_DIR/latest.json"
HISTORY_FILE="$REPORT_DIR/history.jsonl"
TOOLS="cap fx span tap"

fail() {
    printf >&2 'self-host-check: %s\n' "$1"
    exit 1
}

require() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fail "required command not found: $1"
    fi
}

json_number() {
    key=$1
    file=$2
    sed -n "s/.*\"$key\":\([0-9][0-9]*\).*/\1/p" "$file" | head -n 1
}

json_string() {
    key=$1
    file=$2
    sed -n "s/.*\"$key\":\"\([^\"]*\)\".*/\1/p" "$file" | head -n 1
}

line_count() {
    wc -l < "$1" | tr -d ' '
}

percent_saved() {
    raw=$1
    bounded=$2
    if [ "$raw" -le 0 ]; then
        printf '%s\n' 0
    elif [ "$bounded" -ge "$raw" ]; then
        printf '%s\n' 0
    else
        printf '%s\n' $(( (raw - bounded) * 100 / raw ))
    fi
}

build_tools() {
    mkdir -p "$BIN_DIR"
    for tool in $TOOLS; do
        repo="$PARENT_DIR/$tool"
        [ -d "$repo" ] || fail "missing sibling repo: $repo"
        printf '==> building %s\n' "$tool"
        (cd "$repo" && cargo build --quiet)
        cp "$repo/target/debug/$tool" "$BIN_DIR/$tool"
    done
}

check_cap() {
    work=$1
    cap_json="$work/cap.json"

    (
        cd "$work"
        PATH="$BIN_DIR:$PATH" cap --bytes 80 --json -- sh -c '
            i=0
            while [ "$i" -lt 200 ]; do
                printf "line-%03d abcdefghijklmnopqrstuvwxyz\n" "$i"
                i=$((i + 1))
            done
        ' > "$cap_json"
    )

    shown=$(json_number shown_bytes "$cap_json")
    total=$(json_number total_bytes "$cap_json")
    log_path=$(json_string full_log_path "$cap_json")

    [ -n "$shown" ] || fail "cap did not report shown_bytes"
    [ -n "$total" ] || fail "cap did not report total_bytes"
    [ "$total" -gt "$shown" ] || fail "cap did not reduce visible output"
    [ -f "$work/$log_path" ] || fail "cap full log is missing"

    log_lines=$(grep -c 'line-' "$work/$log_path")
    [ "$log_lines" -ge 200 ] || fail "cap full log did not retain full evidence"

    CAP_TOTAL=$total
    CAP_SHOWN=$shown
    CAP_SAVED=$(percent_saved "$total" "$shown")
}

check_span() {
    work=$1
    span_out="$work/span.out"
    source_file="$PARENT_DIR/cap/src/main.rs"

    PATH="$BIN_DIR:$PATH" span --symbol run_command "$PARENT_DIR/cap/src" > "$span_out"

    range=$(sed -n 's/^range: \([0-9][0-9]*\)\.\.\([0-9][0-9]*\)$/\1 \2/p' "$span_out" | head -n 1)
    [ -n "$range" ] || fail "span did not report a range"

    start=$(printf '%s\n' "$range" | sed 's/ .*//')
    end=$(printf '%s\n' "$range" | sed 's/.* //')
    full_lines=$(line_count "$source_file")
    span_lines=$((end - start + 1))

    [ "$span_lines" -gt 0 ] || fail "span produced an invalid line count"
    [ "$span_lines" -lt "$full_lines" ] || fail "span did not reduce source context"

    SPAN_FULL_LINES=$full_lines
    SPAN_LINES=$span_lines
    SPAN_SAVED=$(percent_saved "$full_lines" "$span_lines")
}

check_fx() {
    work=$1
    fx_root="$work/fx-root"
    fx_json="$work/fx.json"
    mkdir "$fx_root"

    (
        cd "$fx_root"
        git init -q
        PATH="$BIN_DIR:$PATH" fx --json --quiet -- sh -c '
            printf "fn main() {}\n" > main.rs
            printf "# lock\n" > Cargo.lock
        ' > "$fx_json"
    )

    grep '"tool":"fx"' "$fx_json" >/dev/null || fail "fx did not produce JSON"
    grep '"source_files_changed":true' "$fx_json" >/dev/null || fail "fx missed source summary"
    grep '"lockfiles_touched":true' "$fx_json" >/dev/null || fail "fx missed lockfile summary"

    FX_EFFECTS=$(json_number effect_count "$fx_json")
    [ -n "$FX_EFFECTS" ] || fail "fx did not report effect_count"
}

check_tap() {
    work=$1
    input="$work/events.jsonl"
    output="$work/events.copy"
    tap_json="$work/tap.json"

    {
        printf '{"level":"info","count":1}\n'
        printf '{"level":"error","count":2}\n'
    } > "$input"

    PATH="$BIN_DIR:$PATH" tap --json --json-shape < "$input" > "$output" 2> "$tap_json"
    cmp -s "$input" "$output" || fail "tap changed stdout bytes"
    grep '"tool":"tap"' "$tap_json" >/dev/null || fail "tap did not report JSON"
    grep '"json_shape":' "$tap_json" >/dev/null || fail "tap did not report JSON shape"

    TAP_BYTES=$(json_number bytes "$tap_json")
    [ -n "$TAP_BYTES" ] || fail "tap did not report byte count"
}

check_composition() {
    work=$1
    composed_root="$work/composed-root"
    cap_fx_json="$work/cap-fx.json"
    mkdir "$composed_root"

    (
        cd "$composed_root"
        git init -q
        PATH="$BIN_DIR:$PATH" cap --bytes 200 --json -- fx --quiet -- sh -c '
            printf "data\n" > composed.txt
        ' > "$cap_fx_json"
    )

    shown=$(json_number shown_bytes "$cap_fx_json")
    total=$(json_number total_bytes "$cap_fx_json")
    log_path=$(json_string full_log_path "$cap_fx_json")

    [ -n "$shown" ] || fail "cap+fx did not report shown_bytes"
    [ -n "$total" ] || fail "cap+fx did not report total_bytes"
    [ -f "$composed_root/$log_path" ] || fail "cap+fx full log is missing"
    grep 'created composed.txt' "$composed_root/$log_path" >/dev/null || fail "cap+fx log missed fx effect"

    COMPOSED_SHOWN=$shown
    COMPOSED_TOTAL=$total
}

write_report() {
    mkdir -p "$REPORT_DIR"
    generated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    cat > "$REPORT_FILE" <<EOF
{"generated_at":"$generated_at","cap":{"raw_bytes":$CAP_TOTAL,"visible_bytes":$CAP_SHOWN,"visible_reduction_percent":$CAP_SAVED},"span":{"full_file_lines":$SPAN_FULL_LINES,"span_lines":$SPAN_LINES,"line_reduction_percent":$SPAN_SAVED},"fx":{"effect_count":$FX_EFFECTS,"source_and_lockfile_summary_ok":true},"tap":{"bytes":$TAP_BYTES,"pass_through_ok":true},"composition":{"cap_fx_total_bytes":$COMPOSED_TOTAL,"cap_fx_visible_bytes":$COMPOSED_SHOWN,"ok":true}}
EOF
    cat "$REPORT_FILE" >> "$HISTORY_FILE"
}

main() {
    require cargo
    require git
    require sed
    require grep
    require cmp
    require wc

    build_tools

    work="${TMPDIR:-/tmp}/bounded-terminal-self-host.$$"
    mkdir "$work"
    trap 'rm -rf "$work"' EXIT HUP INT TERM

    check_cap "$work"
    check_span "$work"
    check_fx "$work"
    check_tap "$work"
    check_composition "$work"
    write_report

    printf 'self-host check passed\n'
    printf 'report: %s\n' "$REPORT_FILE"
    printf 'cap visible reduction: %s%% (%s -> %s bytes)\n' "$CAP_SAVED" "$CAP_TOTAL" "$CAP_SHOWN"
    printf 'span line reduction: %s%% (%s -> %s lines)\n' "$SPAN_SAVED" "$SPAN_FULL_LINES" "$SPAN_LINES"
}

main "$@"
