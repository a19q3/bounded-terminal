# Claude Code Skill Rules

For terminal-heavy work:

- Wrap noisy commands with `cap`.
- Use `span` instead of reading whole files when possible.
- Use `span --backend auto` for symbol bodies when `ast-outline` or `ast-bro` is installed.
- Use `ast-outline` or `ast-bro` directly for outlines, graphs, semantic search, or structural rewrites.
- Run mutating commands through `fx` when side effects matter.
- Use `tap` for stream shape and samples.
- Run `sh scripts/self-host-check.sh` and `sh scripts/community-benchmark.sh` before community-facing benchmark claims.

Keep the tools small and composable. Do not convert them into a framework.
