# Thesis

AI coding agents spend a surprising amount of context on terminal accidents:

- commands that print too much;
- source files read wholesale when one block would do;
- commands that mutate files without a compact receipt;
- pipelines debugged by dumping large intermediate data.

`bounded-terminal` provides small Unix-style primitives for bounded terminal work:

```text
cap   = do not flood me
span  = do not paste the whole file
fx    = tell me what changed
tap   = show me the stream without breaking it
tx    = let me mutate safely, planned
```

The tools are not a framework. They are intended to compose with existing commands and to preserve standard shell expectations:

- command wrappers preserve wrapped exit codes;
- data stays on stdout where appropriate;
- diagnostics and summaries go to stderr;
- JSON and receipt files are available for agent consumption;
- limitations are stated explicitly.

## Design Goal

Reduce accidental context expansion, not replace developer judgement.

## Non-Goals

- No AI assistant UI.
- No CI dashboard.
- No universal sandbox.
- No promise that heuristics are full parsers.
- No hidden telemetry.

