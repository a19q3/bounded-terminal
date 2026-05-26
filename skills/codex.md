# Codex Skill Rules

Use bounded-terminal when working in large or noisy repositories.

```text
Use cap for commands with unknown output volume.
Use span for code context when a file, line, pattern, or symbol is known.
Use fx when a command may mutate files.
Use tap when inspecting a pipeline or stream.
Prefer JSON and receipt modes when the result will be consumed by another tool or agent step.
```

Do not hide command failures. Preserve exit codes and report any tool limitation clearly.

