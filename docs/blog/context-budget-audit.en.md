# Bounded Terminal: Cutting Token Waste in Agentic Terminal Work

GitHub: [a19q3/bounded-terminal.git](https://github.com/a19q3/bounded-terminal.git)

For many years, terminal work had a simple shape: a human decided what to do, ran a command, read some output, and chose the next step. If output was too long, we used `less`. If a file was too large, we used `grep`. If a command looked risky, we checked `git status` first. This discipline worked because humans pause, filter, remember context, and occasionally remove their hands from the keyboard. In theory, at least.

AI coding agents amplify the same loop. They run tests more often, search repositories more aggressively, inspect files repeatedly, invoke formatters, run generators, and check diffs. Each action can be reasonable in isolation, but together they create a new kind of waste: the terminal is unbounded, while the agent context window is not.

A single noisy `cargo test`, a broad `rg`, or an unnecessary whole-file read can push thousands of low-value tokens into the conversation. The model then has to reason through the noise. That is not a model intelligence problem. It is often an interface problem: we are still treating terminal tools as displays for patient humans, while agents need compact receipts.

An agent usually needs answers to questions like:

- What was the real exit code?
- How much output is worth showing now?
- Where is the full log if we need evidence later?
- Which syntactic unit contains this line?
- What files did this command create, modify, or delete?
- What shape does this stream have without dumping the stream?

Modern agent terminal work is no longer just:

```text
command -> output
```

It is closer to:

```text
intent -> command -> observation -> decision -> mutation -> verification
```

Every stage can expand. Output expands. Source context expands. File-state ambiguity expands. Pipeline debugging expands. That expansion costs tokens, and it also costs attention. The context window is not a bin. It is a budget.

`cap`, `span`, `fx`, and `tap` were built from that premise. They are not an AI coding assistant. The world has enough glowing assistants. What is missing is a small set of boring, composable tools that keep terminal work bounded.

The goal is narrow:

> make command output, source context, file effects, and pipe data flow bounded, observable, and reproducible.

That narrow goal is exactly why the tools can save a lot of tokens in practice.

## The Four Primitives

| Tool | What it bounds or observes | What it does not try to be |
| --- | --- | --- |
| `cap` | command output, with full log retention | a CI dashboard or log analysis engine |
| `span` | source context around a line, pattern, or symbol | an IDE, call graph, or rewrite engine |
| `fx` | command-level file effects | a sandbox or rollback system |
| `tap` | pipe data flow without changing stdout | a logging platform |

I am opinionated about the shape of these tools: small tools are easier to trust. `cap` should not become a dashboard. `span` should not become an IDE. `fx` should not pretend to be a security sandbox. `tap` should not become a hosted observability product. Each tool should do one thing, expose a clear receipt, and compose with normal shell workflows.

## Where Token Waste Comes From

A typical agent development turn often looks like this:

```text
cargo test             -> output may be huge
cat src/main.rs        -> context may be too broad
cargo fmt              -> file effects may be unclear
producer | jq | sink   -> intermediate data may get dumped
```

Each step contains a "look at too much" trap.

The usual shell workaround is not quite enough:

```sh
cargo test 2>&1 | head -c 4000
```

That may hide the exit code, merge stdout and stderr too early, lose the failure tail, discard the full log, and still leave the agent guessing what happened. It is a clever one-liner, but a poor primitive. A biscuit tin is not a filing system, despite what some offices appear to believe.

The same applies to source inspection:

```sh
sed -n '200,280p' src/main.rs
cat src/main.rs
```

Line slicing is often arbitrary, and whole-file reads are expensive. The useful unit is usually a function, method, impl block, class, test case, or fenced code block.

For file effects, `git status` and `git diff` are useful, but they do not answer the command-level question cleanly: what did this command change?

For pipelines, dumping intermediate files works, but it changes the workflow and often sends unnecessary data straight into the context window.

## The Token Audit Model

We do want large token savings. That is a core benefit. But we should measure it carefully.

Exact token counts depend on the tokenizer, language, symbol density, and output format. Rust compiler errors, JSONL, ANSI logs, Chinese prose, and stack traces all tokenize differently. So the first measurement layer should use more stable proxies:

1. **Bytes** for command output, logs, and stream data.
2. **Lines** for source context.
3. **Visible evidence** for what the agent actually sees.
4. **Retained evidence** for the full logs or receipts kept outside the immediate context.

A rough estimate is still useful:

```sh
raw_bytes=7200
visible_bytes=99

awk -v raw="$raw_bytes" -v shown="$visible_bytes" '
  BEGIN {
    saved = raw - shown
    reduction = saved * 100 / raw
    # Rough English/code CLI estimate. Not accounting-grade truth.
    estimated_tokens_saved = saved / 4
    printf "visible reduction: %.1f%%\n", reduction
    printf "rough tokens avoided: %.0f\n", estimated_tokens_saved
  }
'
```

This is not precision accounting. It is a pragmatic instrument panel: first remove the obvious context waste, then decide whether tokenizer-level measurement is worth the extra machinery. The practical claim is stronger than "nicer logs": bounded terminal primitives move high-volume, low-decision-value text out of the agent's immediate context while keeping full evidence recoverable. That is exactly the kind of waste that usually consumes context before it improves the answer.

## `cap`: Bound Noisy Command Output

`cap` runs a command, preserves its exit status, stores full logs, and shows only a bounded view:

```sh
cap --bytes 12000 -- cargo test
cap --focus error -- cargo check
cap --json -- npm test
```

This changes the agent interaction pattern. The agent can read a compact failure view first, while the complete evidence remains in `.cap/logs/` for later inspection. It does not need to rerun the same noisy command just because the first view was truncated.

In a local self-host sample:

```text
raw command output: 7200 bytes
visible output:       99 bytes
visible reduction:    98%
rough tokens avoided: about 1,775 tokens
```

That does not mean every project saves 98%. It means noisy output is a large and easy class of accidental token expansion, and `cap` blocks it early. In token-budget terms, this is the cheapest win: do not ask the model to carry thousands of bytes of log material when the decision usually depends on the exit code, the failure focus, and the path to the retained full log.

## `span`: Bound Source Context

When an error points to a line, agents often read too much:

```text
src/main.rs:360: ...
```

The tempting mistake is to read the whole file. `span` instead returns the containing context:

```sh
span src/main.rs:360
span --contains "unwrap()" src
span --backend auto --explain --symbol run_command src
```

By default, `span` uses a heuristic backend. If `ast-outline` or `ast-bro` is installed, `--backend auto` can use them for stronger extraction while still enforcing `--max-lines`. That is the important contract: `span` is a bounded context facade, not a replacement for AST tooling.

Local self-host measurements:

```text
full file:          1120 lines
span heuristic:       84 lines   -> 92% line reduction
span auto backend:    20 lines   -> 98% line reduction via ast-outline
```

Using a rough 50-80 characters per line and about four characters per token for English/code-like output, avoiding a thousand unnecessary source lines can easily avoid tens of thousands of tokens. The exact number varies. The direction does not. Source context is often the most expensive hidden leak in an agent session, because one over-broad file read stays in the conversation even after the relevant function has been found.

## `fx`: Stop Guessing What Changed

Many agent turns include:

```sh
cargo fmt
cargo test
git diff
```

`git diff` can be large, and `git status` does not say what happened because of one command. `fx` wraps a command and emits a file-effect receipt:

```sh
fx --json -- cargo fmt
fx --watch-path crates/parser -- cargo test -p parser
```

It reports created, modified, and deleted paths, adds Git classification where available, and summarises whether source files, lockfiles, or ignored files changed.

`fx` does not always save tokens by compressing a huge output immediately. Its value is that it prevents several follow-up turns of uncertainty:

```text
Did this touch source?
Did it modify Cargo.lock?
Was that only target/ cache?
Did a generator create fixtures?
```

That is still token saving. It is just saving the investigative sprawl rather than one single printed blob.

## `tap`: Observe Streams Without Dumping Them

Pipeline debugging often turns into temporary files:

```sh
producer > /tmp/a
head /tmp/a
wc -l /tmp/a
filter < /tmp/a > /tmp/b
head /tmp/b
```

`tap` keeps stdout unchanged and writes observations to stderr:

```sh
cat events.jsonl \
  | tap --label raw --json-shape \
  | jq '.level' \
  | tap --label levels
```

You get bytes, lines, throughput, samples, binary detection, and best-effort JSONL field shape without breaking the pipeline.

In the local benchmark:

```text
tap pipeline: 90 bytes in, 90 bytes out, pass-through ok
```

The point is not that 90 bytes were compressed. The point is that the stream shape was inspected without dumping intermediate data into the conversation.

## Reproducible Local Measurements

From the current checkout:

```text
Generated: 2026-05-27T03:10:18Z

cap noisy output:      15600 bytes -> 139 bytes, 99% visible reduction
span heuristic:         1120 lines -> 84 lines, 92% line reduction
span auto:              1120 lines -> 30 lines, 97% line reduction via ast-outline
fx file effects:        2 effects, source + lockfile summary ok
tap pipeline:           stdout pass-through ok
```

Reproduce:

```sh
sh scripts/self-host-check.sh
sh scripts/community-benchmark.sh
sed -n '1,120p' reports/community/latest.md
```

These are local measurements, not universal productivity claims. A cautious statement is:

> In noisy command and over-broad source inspection scenarios, local samples show roughly 90%+ visible context reduction. Across real agent development sessions, a 50-85% reduction in accidental context expansion is a plausible target range, depending heavily on workflow.

The more operational statement is this: bounded terminal work can make token saving a structural property of the workflow rather than a matter of agent self-control. Instead of hoping the agent remembers to be frugal, the terminal surface returns compact evidence by default and stores the bulky evidence outside the prompt.

If a session only runs tiny commands and reads small files, these tools will not magically save much. But if the workflow includes noisy tests, broad searches, long files, generators, or pipeline debugging, token reduction becomes a primary benefit rather than a nice side effect. In those settings, the claim is not merely that fewer tokens are printed once; it is that fewer unnecessary tokens are dragged through every later reasoning step.

## How I Use Them

My default rules:

```text
1. Use cap for commands with unknown or potentially large output.
2. Use span when a file:line, symbol, or pattern is known. Do not read the whole file first.
3. Use fx around commands that may mutate files.
4. Use tap for pipeline debugging instead of dumping intermediate data.
5. Use tx in the future for broad mutations; for now, at least use fx to observe effects.
```

Composed:

```sh
rg -n "run_command" cap/src cap/tests
span --backend auto --explain cap/src/main.rs:250

cap --focus error -- cargo test
fx --json -- cargo fmt

cat reports/community/latest.json \
  | tap --label report --json-shape \
  | jq '.scenarios.cap_noisy_output'
```

The value is not replacing the shell. It is making shell-driven agent work less wasteful and more auditable. If every step of the loop is unbounded, the agent wastes context and the human wastes patience. Both are expensive, though humans tend to invoice with more theatrical confidence.

That is why I prefer the phrase:

```text
bounded terminal primitives
```

It sounds like tooling rather than a keynote slide, which is very much the point.
