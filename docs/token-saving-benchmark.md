# Token-Saving Benchmark Plan

This project should avoid exaggerated claims. Measure visible-output reduction before claiming a percentage.

## Scenarios

1. Noisy Rust test output.
2. Large recursive text search.
3. Source context lookup from a compiler error.
4. File-effect observation after a codegen or test command.
5. JSONL pipeline inspection.

## Measurement

For each scenario record:

```text
raw command
raw visible bytes
bounded command
bounded visible bytes
full evidence location
exit code preserved: yes/no
manual usefulness notes
```

## Self-Hosting Canary

Run:

```sh
sh scripts/self-host-check.sh
```

The script records a synthetic canary report at:

```text
reports/self-host/latest.json
```

Use this report as a regression guard for:

- visible output reduction from `cap`;
- line-context reduction from `span`;
- stdout integrity from `tap`;
- file-effect summary correctness from `fx`;
- basic `cap` + `fx` composition.

These numbers are allowed in development notes. Do not use them as public productivity claims without a real workflow measurement.

## Example Table

| Scenario | Raw bytes | Bounded bytes | Evidence preserved | Notes |
| --- | ---: | ---: | --- | --- |
| cargo test failure | TBD | TBD | `.cap/logs/...` | Measure on a real repo. |
| source context | TBD | TBD | source file path/range | Compare whole-file read to `span`. |
| file effects | TBD | TBD | `fx --receipt` | Compare against raw diff/status. |

## Rule

Say “reduces accidental context expansion” unless the saving is measured.
