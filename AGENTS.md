# AGENTS.md

This repository coordinates the bounded-terminal toolset. The work is not merely to improve four CLIs; the work is to make agent terminal behaviour more bounded, observable, and measurable while developing the tools themselves.

## Self-Hosting Goal

Future optimisation work must use the toolkit as soon as the local binaries pass the self-host check. The tools should become the normal development substrate for their own development:

- `cap` bounds noisy command output while preserving full logs.
- `span` extracts code context instead of reading whole files.
- `fx` records filesystem effects from mutating commands.
- `tap` inspects streams without changing stdout.

This is self-hosting only if the agent uses these tools during development and records whether they reduced accidental context expansion.

## Required Start

At the beginning of a meaningful development session, run:

```sh
sh scripts/self-host-check.sh
```

This builds local sibling repos, runs cross-tool smoke checks, and writes:

```text
reports/self-host/latest.json
reports/self-host/history.jsonl
```

Use the generated local binaries from:

```text
.self-host/bin/
```

When invoking tools manually inside this repository, prefer:

```sh
PATH="$(pwd)/.self-host/bin:$PATH"
```

## Command Rules

Use these rules during all future optimisation work:

1. Potentially large commands go through `cap`.
2. Known source locations, symbols, or patterns are inspected with `span` before reading whole files.
3. Use `span --backend auto` when `ast-outline` or `ast-bro` is installed and a stronger symbol body extractor is useful.
4. Use `ast-outline` or `ast-bro` directly for repo outlines, graphs, semantic search, or structural rewrites; wrap noisy runs with `cap` and mutating runs with `fx`.
5. Commands that may create, modify, delete, format, generate, install, migrate, or rewrite files go through `fx --quiet` or are followed by an `fx` receipt.
6. Pipeline debugging uses `tap`; do not dump large intermediate files merely to inspect shape.
7. JSON or receipt modes are preferred when another agent step will consume the result.
8. Do not hide wrapped command failures. Preserve and report exit codes.
9. Do not add heavy dependencies unless they materially improve correctness.

## Production Gate

Before calling a change production-ready, run:

```sh
sh scripts/production-check.sh
```

Run this command directly. Do not wrap `production-check.sh` or `self-host-check.sh` in `cap`, because those scripts already exercise `cap` internally and nested `cap` runs can distort the self-host canary on macOS.

The gate runs, for each tool:

```sh
cargo fmt --check
cargo clippy -- -D warnings
cargo test
git diff --check
```

It also runs shell syntax checks and the self-hosting composition test.

The production gate also checks that `install.sh` pins match the current sibling repo heads, that fresh remote refs have been fetched, that sibling tool repos are clean and synced with their remotes, and that the umbrella repository itself is clean:

```sh
sh scripts/verify-pins.sh
```

If the local sandbox cannot reach GitHub, use `VERIFY_PINS_FETCH=0 sh scripts/verify-pins.sh` only as an offline fallback and state that remote freshness was not rechecked in that run.

## Efficiency Evidence

Do not claim efficiency improvement without measurement. The accepted minimum evidence is the latest self-host report:

```sh
cat reports/self-host/latest.json
```

The report records:

- `cap.visible_reduction_percent`
- `span.line_reduction_percent`
- `tap.pass_through_ok`
- `fx.source_and_lockfile_summary_ok`
- `composition.ok`

For real release notes, synthetic self-host numbers are not enough. Add at least one real-workflow measurement from a noisy build, large search, compiler error, or JSONL pipeline.

## Development Loop

Use this loop:

1. Run `sh scripts/self-host-check.sh` and note baseline metrics.
2. Use `span` for targeted code inspection.
3. Use `cap` for test/build/check commands with noisy output.
4. Use `fx --quiet` around risky mutations.
5. Use `tap` for stream or JSONL debugging.
6. Run focused tool tests.
7. Push tool repo commits before updating or relying on pinned installer revisions.
8. Run `sh scripts/production-check.sh`.
9. Summarise changed behaviour, test results, pin status, and latest efficiency metrics.

## Limits

The current self-host report proves the tools compose and reduce synthetic context expansion. It does not prove broad productivity gains. Treat it as a regression guard and a minimum signal, not a marketing claim.
