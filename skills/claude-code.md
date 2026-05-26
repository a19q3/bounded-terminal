# Claude Code Skill Rules

For terminal-heavy work:

- Wrap noisy commands with `cap`.
- Use `span` instead of reading whole files when possible.
- Run mutating commands through `fx` when side effects matter.
- Use `tap` for stream shape and samples.

Keep the tools small and composable. Do not convert them into a framework.

