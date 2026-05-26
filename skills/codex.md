# Codex Skill Rules

Use bounded-terminal when working in large or noisy repositories.

```text
Use cap for commands with unknown output volume.
Use span for code context when a file, line, pattern, or symbol is known.
Use span --backend auto when ast-outline or ast-bro is installed and a stronger symbol extractor is useful.
Use ast-outline/ast-bro directly for outlines, graphs, semantic search, or rewrites; wrap noisy runs with cap and mutating runs with fx.
Use fx when a command may mutate files.
Use tap when inspecting a pipeline or stream.
Prefer JSON and receipt modes when the result will be consumed by another tool or agent step.
```

Run `sh scripts/self-host-check.sh` before meaningful optimisation work and `sh scripts/community-benchmark.sh` before community-facing notes. Do not hide command failures. Preserve exit codes and report any tool limitation clearly.
