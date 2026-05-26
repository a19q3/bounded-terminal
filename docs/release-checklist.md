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
- `sh scripts/self-host-check.sh` passes and writes `reports/self-host/latest.json`.
- `sh scripts/verify-pins.sh` fetches fresh remote refs and confirms `install.sh` pins match clean, synced sibling repos.
- In a network-restricted sandbox, `VERIFY_PINS_FETCH=0 sh scripts/verify-pins.sh` is acceptable only as an explicitly reported offline fallback after the tool repos have been pushed.
- `sh scripts/production-check.sh` passes from a clean umbrella repository before a production-ready tag. Run it directly, not under `cap`, because it already invokes `cap` internally.
- `AGENTS.md` self-hosting rules match the current tool contracts.
