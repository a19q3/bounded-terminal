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

## Example Table

| Scenario | Raw bytes | Bounded bytes | Evidence preserved | Notes |
| --- | ---: | ---: | --- | --- |
| cargo test failure | TBD | TBD | `.cap/logs/...` | Measure on a real repo. |
| source context | TBD | TBD | source file path/range | Compare whole-file read to `span`. |
| file effects | TBD | TBD | `fx --receipt` | Compare against raw diff/status. |

## Rule

Say “reduces accidental context expansion” unless the saving is measured.

