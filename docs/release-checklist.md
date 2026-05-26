# Release Checklist

Run for each tool before a v0.1 tag:

```sh
cargo fmt --check
cargo clippy -- -D warnings
cargo test
```

Manual checks:

- README examples run or are clearly illustrative.
- JSON examples in `docs/json.md` match current output shape.
- Wrapped command exit codes are preserved.
- stdout/stderr contract is documented.
- Secret-sensitive behaviour is documented.
- Limitations are explicit.
- No heavy dependency was added without a correctness reason.

Umbrella checks:

- `install.sh` installs all four tools from their public Git repositories.
- `docs/agent-rules.md` matches the individual repo guidance.
- Benchmark document avoids unmeasured marketing claims.

