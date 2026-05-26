# Examples

## Noisy Test Output

Before:

```sh
cargo test
```

After:

```sh
cap -- cargo test
cap --focus error -- cargo test
cap show "$(cap logs | tail -n 1)"
```

`cap` keeps visible output bounded while storing a redacted full log under `.cap/logs/`.

## Code Context

Before:

```sh
sed -n '1,260p' src/lib.rs
```

After:

```sh
span src/lib.rs:128
span --contains "unwrap()" src/
span --symbol verify_proof_plan crates/
span --backend auto --symbol verify_proof_plan crates/
```

`span` returns the containing block or a bounded line-window fallback.

When `ast-outline` or `ast-bro` is installed, `--backend auto` can delegate a known symbol body to the stronger AST tool while keeping `span` as the bounded front door.

## File Effects

Before:

```sh
cargo test
git status --short
git diff --stat
```

After:

```sh
fx --receipt .fx/receipts/test.json -- cargo test
```

`fx` reports created, modified, and deleted files plus summary flags.

## Pipeline Inspection

Before:

```sh
cat events.jsonl > /tmp/events.txt
head /tmp/events.txt
```

After:

```sh
cat events.jsonl | tap --json-shape | jq '.level'
cat blob.bin | tap --hexdump | parser
```

`tap` preserves stdout byte-for-byte and writes observations to stderr.
