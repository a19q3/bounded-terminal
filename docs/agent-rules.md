# Agent Rules

Use these rules in `AGENTS.md`, Codex instructions, Claude Code instructions, Cursor rules, or similar agent policy files.

```text
1. Never run commands with unknown or potentially large output directly. Use cap.
2. Prefer cap --focus error for failing builds and tests after the first noisy run.
3. Use rg/fd to locate candidates, then span for syntax-bounded context.
4. Do not read whole source files when FILE:LINE, --contains, or --symbol can identify the relevant block.
5. Use fx around commands that may generate, rewrite, install, test, or migrate files.
6. Use fx --receipt when later reasoning needs a stable file-effect record.
7. Use tap for pipeline inspection; do not dump large intermediate files unless required.
8. Treat cap logs as redacted evidence by default, not secret storage.
9. Do not add heavy dependencies to these tools without a correctness justification.
10. Preserve wrapped command exit codes.
```

## Suggested Codex Rule

```text
For terminal work, prefer bounded-terminal tools:
- cap for noisy commands;
- span for code context;
- fx for side-effect observation;
- tap for pipeline inspection.
Keep command output bounded and prefer receipts when results will be consumed later.
```

