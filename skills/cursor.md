# Cursor Rules

Recommended project rule:

```text
When using terminal commands, prefer bounded-terminal tools:
cap for command output, span for code context, fx for file effects, tap for pipelines.
Use span --backend auto when ast-outline or ast-bro can provide a better symbol body.
Use ast-outline/ast-bro directly for deeper AST tasks, wrapped with cap/fx when noisy or mutating.
Avoid dumping large command output or whole files into the chat when bounded context is available.
```
