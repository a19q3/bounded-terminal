# AST Tool Cooperation

`bounded-terminal` does not try to replace full AST navigation tools. Its boundary is terminal work: bounded output, bounded context, file-effect receipts, and pipe observation.

## Tool Boundaries

| Need | Prefer |
| --- | --- |
| Known `FILE:LINE` context | `span FILE:LINE` |
| Known symbol body with stronger AST support installed | `span --backend auto --symbol NAME PATH` |
| Repository outline or digest | `ast-outline` or `ast-bro` |
| Call graph, dependency graph, semantic search | `ast-bro` or an LSP |
| Structural search or rewrite | `ast-bro` / `ast-grep`, wrapped by `fx` and later `tx` |
| Noisy AST command output | `cap -- ast-outline ...` or `cap -- ast-bro ...` |

## Recommended Composition

Use `span` as the bounded context front door:

```sh
span src/main.rs:120
span --backend auto src/main.rs:120
span --backend ast-outline --symbol parse_args src/
```

Use stronger AST tools directly when the task needs their larger surface area:

```sh
cap -- ast-outline digest src/
cap -- ast-bro graph src/
fx --quiet -- ast-bro run -p 'foo($A)' -r 'bar($A)' --write
```

## Agent Rule

Do not duplicate `ast-outline` or `ast-bro` inside this toolkit. If a task needs outline, graph, semantic search, or structural rewrite, call the specialised tool and wrap it with `cap`, `fx`, and eventually `tx` as appropriate.

`span` should remain the small primitive for bounded context extraction. External AST tools are optional backends, not required dependencies.
