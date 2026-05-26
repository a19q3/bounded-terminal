# bounded-terminal Community Report

`bounded-terminal` is a set of small Unix-style primitives for bounded terminal work. It is not an AI coding assistant and does not replace existing developer tools. It makes common agent terminal actions easier to bound, inspect, and reproduce.

## Tool Roles

| Tool | Role | Community Claim |
| --- | --- | --- |
| `cap` | bounded command runner | Prevents noisy commands from flooding visible context while keeping a redacted full log. |
| `span` | bounded code context facade | Keeps a stable `FILE:LINE` / pattern / symbol interface while optionally delegating symbol bodies to AST tools. |
| `fx` | file-effect receipt | Reports command-level created, modified, and deleted files without requiring a large diff. |
| `tap` | pipe observer | Reports stream shape to stderr while preserving stdout byte-for-byte. |

## Why `span` Is Not Replaced By AST Tools

`ast-outline` and `ast-bro` are specialised AST intelligence tools. They are better suited for outlines, module digests, dependency graphs, call graphs, semantic search, and structural rewrites.

`span` remains useful because it is the stable bounded-context front door:

- It works without external tools.
- It preserves a small JSON contract for agents.
- It enforces `--max-lines`.
- It provides `--backend auto` for optional AST delegation.
- It can fall back to heuristic extraction when a backend is unavailable.

Recommended composition:

```sh
span src/main.rs:120
span --backend auto --symbol run_command src/
cap -- ast-outline digest src/
fx --quiet -- ast-bro run -p 'foo($A)' -r 'bar($A)' --write
```

## Local Measurements

Generated locally on 2026-05-26 with:

```sh
sh scripts/self-host-check.sh
sh scripts/community-benchmark.sh
```

These are reproducible measurements from this checkout, not universal productivity claims.

| Scenario | Raw | Bounded / Observed | Result |
| --- | ---: | ---: | --- |
| `cap` noisy output | 15,600 bytes | 139 bytes | 99% visible reduction |
| `span` heuristic context | 814 lines | 75 lines | 90% line reduction |
| `span --backend auto` | 814 lines | 30 lines | 96% line reduction via `ast-outline` |
| `fx` file effects | n/a | 2 effects | source + lockfile summary detected |
| `tap` pipeline | 90 bytes | 90 bytes | stdout pass-through preserved |

Environment:

- `ast-outline`: available
- `ast-bro`: not installed locally
- `span --backend auto`: selected `ast-outline` and truncated output with `--max-lines`

## Non-Claims

- These numbers do not prove a universal productivity percentage.
- `span` is not a full parser, LSP, graph engine, or rewrite engine.
- `fx` observes file effects; it is not a sandbox.
- `tap` samples streams; it is not a log database.
- `cap` stores redacted logs by default; it is not raw secret storage.

The claim is intentionally narrower: these tools reduce accidental context expansion and make terminal work more observable during agent-assisted development.
