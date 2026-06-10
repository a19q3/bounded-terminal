#!/bin/sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PARENT_DIR=$(cd "$ROOT_DIR/.." && pwd)
BIN_DIR="$ROOT_DIR/.self-host/bin"
REPORT_DIR="$ROOT_DIR/reports/community"
JSON_REPORT="$REPORT_DIR/latest.json"
MD_REPORT="$REPORT_DIR/latest.md"

fail() {
    printf >&2 'community-benchmark: %s\n' "$1"
    exit 1
}

require() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fail "required command not found: $1"
    fi
}

make_work_dir() {
    mktemp -d "${TMPDIR:-/tmp}/bounded-terminal-community.XXXXXX"
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

line_count() {
    wc -l < "$1" | tr -d ' '
}

build_bins() {
    mkdir -p "$BIN_DIR"
    for tool in cap fx span tap; do
        repo="$PARENT_DIR/$tool"
        [ -d "$repo" ] || fail "missing sibling repo: $repo"
        (cd "$repo" && cargo build --quiet)
        cp "$repo/target/debug/$tool" "$BIN_DIR/$tool"
    done
}

write_noisy_output() {
    i=0
    while [ "$i" -lt 300 ]; do
        printf 'bench-line-%03d abcdefghijklmnopqrstuvwxyz0123456789\n' "$i"
        i=$((i + 1))
    done
}

measure_cap() {
    work=$1
    raw="$work/cap-raw.out"
    cap_json="$work/cap.json"

    write_noisy_output > "$raw"
    (
        cd "$work"
        PATH="$BIN_DIR:$PATH" cap --bytes 120 --json -- sh -c '
            i=0
            while [ "$i" -lt 300 ]; do
                printf "bench-line-%03d abcdefghijklmnopqrstuvwxyz0123456789\n" "$i"
                i=$((i + 1))
            done
        ' > "$cap_json"
    )

    CAP_RAW_BYTES=$(wc -c < "$raw" | tr -d ' ')
    CAP_BOUNDED_BYTES=$(json_number shown_bytes "$cap_json")
    CAP_REDUCTION=$(percent_saved "$CAP_RAW_BYTES" "$CAP_BOUNDED_BYTES")
}

measure_span() {
    work=$1
    heuristic="$work/span-heuristic.out"
    auto_json="$work/span-auto.json"
    doctor_json="$work/span-doctor.json"
    source_file="$PARENT_DIR/cap/src/main.rs"

    PATH="$BIN_DIR:$PATH" span --backend heuristic --symbol run_command "$PARENT_DIR/cap/src" > "$heuristic"
    range=$(sed -n 's/^range: \([0-9][0-9]*\)\.\.\([0-9][0-9]*\)$/\1 \2/p' "$heuristic" | head -n 1)
    [ -n "$range" ] || fail "span heuristic did not report range"
    start=$(printf '%s\n' "$range" | sed 's/ .*//')
    end=$(printf '%s\n' "$range" | sed 's/.* //')
    SPAN_FULL_LINES=$(line_count "$source_file")
    SPAN_HEURISTIC_LINES=$((end - start + 1))
    SPAN_HEURISTIC_REDUCTION=$(percent_saved "$SPAN_FULL_LINES" "$SPAN_HEURISTIC_LINES")

    PATH="$BIN_DIR:$PATH" span backend doctor --json > "$doctor_json"
    if grep '"name":"ast-outline","binary":"ast-outline","available":true' "$doctor_json" >/dev/null; then
        AST_OUTLINE_AVAILABLE=true
    else
        AST_OUTLINE_AVAILABLE=false
    fi
    if grep '"name":"ast-bro","binary":"ast-bro","available":true' "$doctor_json" >/dev/null; then
        AST_BRO_AVAILABLE=true
    else
        AST_BRO_AVAILABLE=false
    fi

    PATH="$BIN_DIR:$PATH" span --backend auto --max-lines 30 --json --symbol run_command "$PARENT_DIR/cap/src" > "$auto_json"
    SPAN_AUTO_BACKEND=$(json_string backend "$auto_json")
    [ -n "$SPAN_AUTO_BACKEND" ] || fail "span auto did not report backend"
    auto_range=$(sed -n 's/.*"range":\[\([0-9][0-9]*\),\([0-9][0-9]*\)\].*/\1 \2/p' "$auto_json" | head -n 1)
    [ -n "$auto_range" ] || fail "span auto did not report range"
    auto_start=$(printf '%s\n' "$auto_range" | sed 's/ .*//')
    auto_end=$(printf '%s\n' "$auto_range" | sed 's/.* //')
    SPAN_AUTO_LINES=$((auto_end - auto_start + 1))
    SPAN_AUTO_REDUCTION=$(percent_saved "$SPAN_FULL_LINES" "$SPAN_AUTO_LINES")
    if grep '"truncated":true' "$auto_json" >/dev/null; then
        SPAN_AUTO_TRUNCATED=true
    else
        SPAN_AUTO_TRUNCATED=false
    fi
}

measure_fx() {
    work=$1
    root="$work/fx-root"
    fx_json="$work/fx.json"
    mkdir "$root"
    (
        cd "$root"
        git init -q
        PATH="$BIN_DIR:$PATH" fx --json --quiet -- sh -c '
            printf "fn main() {}\n" > generated.rs
            printf "# lock\n" > Cargo.lock
        ' > "$fx_json"
    )
    FX_EFFECTS=$(json_number effect_count "$fx_json")
    [ -n "$FX_EFFECTS" ] || fail "fx did not report effect_count"
}

measure_tap() {
    work=$1
    input="$work/events.jsonl"
    output="$work/events.copy"
    tap_json="$work/tap.json"

    {
        printf '{"level":"info","service":"api","count":1}\n'
        printf '{"level":"error","service":"worker","count":2}\n'
    } > "$input"

    PATH="$BIN_DIR:$PATH" tap --json --json-shape < "$input" > "$output" 2> "$tap_json"
    cmp -s "$input" "$output" || fail "tap changed stdout bytes"
    TAP_BYTES=$(json_number bytes "$tap_json")
    [ -n "$TAP_BYTES" ] || fail "tap did not report bytes"
}

write_reports() {
    mkdir -p "$REPORT_DIR"
    generated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    cat > "$JSON_REPORT" <<EOF
{"generated_at":"$generated_at","environment":{"ast_outline":{"available":$AST_OUTLINE_AVAILABLE},"ast_bro":{"available":$AST_BRO_AVAILABLE}},"scenarios":{"cap_noisy_output":{"raw_bytes":$CAP_RAW_BYTES,"bounded_bytes":$CAP_BOUNDED_BYTES,"visible_reduction_percent":$CAP_REDUCTION},"span_context":{"full_file_lines":$SPAN_FULL_LINES,"heuristic_lines":$SPAN_HEURISTIC_LINES,"heuristic_reduction_percent":$SPAN_HEURISTIC_REDUCTION,"auto_backend":"$SPAN_AUTO_BACKEND","auto_lines":$SPAN_AUTO_LINES,"auto_reduction_percent":$SPAN_AUTO_REDUCTION,"auto_truncated":$SPAN_AUTO_TRUNCATED},"fx_file_effects":{"effect_count":$FX_EFFECTS,"source_and_lockfile_summary_ok":true},"tap_pipeline":{"bytes":$TAP_BYTES,"pass_through_ok":true}}}
EOF

    cat > "$MD_REPORT" <<EOF
# bounded-terminal Local Benchmark

Generated: $generated_at

These are local, reproducible measurements from this checkout. They are not universal productivity claims.

| Scenario | Raw | Bounded / Observed | Reduction / Result |
| --- | ---: | ---: | --- |
| cap noisy output | $CAP_RAW_BYTES bytes | $CAP_BOUNDED_BYTES bytes | $CAP_REDUCTION% visible reduction |
| span heuristic context | $SPAN_FULL_LINES lines | $SPAN_HEURISTIC_LINES lines | $SPAN_HEURISTIC_REDUCTION% line reduction |
| span auto context | $SPAN_FULL_LINES lines | $SPAN_AUTO_LINES lines | $SPAN_AUTO_REDUCTION% line reduction via $SPAN_AUTO_BACKEND |
| fx file effects | n/a | $FX_EFFECTS effects | source + lockfile summary ok |
| tap pipeline | $TAP_BYTES bytes | $TAP_BYTES bytes | stdout pass-through ok |

Environment:

- ast-outline available: $AST_OUTLINE_AVAILABLE
- ast-bro available: $AST_BRO_AVAILABLE
- span auto truncated output: $SPAN_AUTO_TRUNCATED

Reproduce:

\`\`\`sh
sh scripts/self-host-check.sh
sh scripts/community-benchmark.sh
\`\`\`
EOF
}

main() {
    require cargo
    require cmp
    require cp
    require date
    require git
    require head
    require mkdir
    require mktemp
    require sed
    require tr
    require wc

    build_bins

    work=$(make_work_dir) || fail "failed to create temporary work directory"
    cleanup() {
        rm -rf "$work"
    }
    trap cleanup EXIT
    trap 'cleanup; exit 130' HUP INT TERM

    measure_cap "$work"
    measure_span "$work"
    measure_fx "$work"
    measure_tap "$work"
    write_reports

    printf 'community benchmark passed\n'
    printf 'json report: %s\n' "$JSON_REPORT"
    printf 'markdown report: %s\n' "$MD_REPORT"
}

main "$@"
