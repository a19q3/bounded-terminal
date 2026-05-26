# bounded-terminal

Bounded terminal primitives for AI coding agents.

`bounded-terminal` is a small toolkit for reducing accidental context expansion in shell-driven coding workflows. It does not replace Unix tools; it wraps the risky parts of agent terminal work with clearer bounds and receipts.

## Tools

| Tool | Primitive | Use it when |
| --- | --- | --- |
| `cap` | bounded command output | A command may produce large or noisy output. |
| `span` | bounded code context | You know a file line, pattern, or symbol and need the containing block. |
| `fx` | file-effect observation | A command may create, modify, or delete files. |
| `tap` | pipe data-flow observation | You need stream stats or samples without changing stdout. |

Planned:

| Tool | Primitive | Status |
| --- | --- | --- |
| `tx` | rollbackable mutation boundary | Planned Git-backed v0.1. |

## Quick Start

```sh
cargo install --git https://github.com/a19q3/cap.git
cargo install --git https://github.com/a19q3/span.git
cargo install --git https://github.com/a19q3/fx.git
cargo install --git https://github.com/a19q3/tap.git
```

Or use:

```sh
sh install.sh
```

## Agent Rules

```text
1. Use cap for commands with unknown or potentially large output.
2. Use span instead of reading whole source files when a line, pattern, or symbol is known.
3. Use fx around commands that may generate, rewrite, install, test, or migrate files.
4. Use tap for pipeline inspection instead of dumping intermediate data.
5. Prefer JSON/receipt modes when another tool or agent will consume the result.
```

## Examples

```sh
cap -- cargo test
span --contains "unwrap()" src/
fx --receipt .fx/receipts/latest.json -- cargo test
cat events.jsonl | tap --json-shape | jq '.level'
```

## Positioning

The thesis is narrow on purpose:

> AI coding agents waste context because terminal work is often unbounded, over-broad, and hard to observe.

These tools reduce accidental verbosity, accidental scope expansion, and accidental state ambiguity.

## Documentation

- [Thesis](docs/thesis.md)
- [Agent Rules](docs/agent-rules.md)
- [Examples](docs/examples.md)
- [Token-Saving Benchmark Plan](docs/token-saving-benchmark.md)
- [Release Checklist](docs/release-checklist.md)

