# Bounded Terminal：把上下文当预算，而不是当垃圾桶

我们做 `cap`、`span`、`fx`、`tap` 不是为了再造一个“AI coding assistant”。老实说，这个世界已经不缺会发光的助手了，缺的是几个不会乱说话、能把终端工作管住的小工具。

这个组合的目标很窄：

> 让命令输出、代码上下文、文件副作用和管道数据流变得有界、可观察、可复现。

这听起来不性感。但大多数 agent 开发过程里的 token 浪费，并不是因为模型喜欢废话，而是因为我们把终端当成了无底洞：测试输出一泻千里，源码一读就是整文件，命令改了什么没人知道，pipeline 调试靠把中间结果 dump 到屏幕上。然后大家开始责怪上下文窗口，仿佛是窗户的问题。

## 这四个工具各管一件事

| Tool | 管什么 | 不管什么 |
| --- | --- | --- |
| `cap` | 命令输出有界，同时保留完整日志 | 不分析全部日志，不替你判断业务正确性 |
| `span` | 按 `FILE:LINE` / pattern / symbol 取语法附近上下文 | 不做 call graph，不做 AST 重写 |
| `fx` | 命令前后文件变化 receipt | 不做沙箱，不承诺数据库或网络回滚 |
| `tap` | pipeline 中的数据形状、样本、吞吐 | 不改变 stdout，不做日志平台 |

我的偏见是：工具越小，越容易被信任。`cap` 不应该变成 CI dashboard；`span` 不应该变成 IDE；`fx` 不应该假装是安全沙箱；`tap` 不应该长成 Datadog。小工具做一件事，边界诚实，才适合被 agent 反复组合。

## Token 审计的基本原则

我们不直接声称“节省了多少 token”。原因很简单：token 取决于模型 tokenizer、语言、符号密度和输出格式。Rust 编译错误、JSONL、中文说明、ANSI 日志，token/byte 比例都不一样。

所以我们先审更稳定的东西：

1. **bytes**：命令输出、日志、管道数据最容易测。
2. **lines**：源码上下文更适合用行数看范围收缩。
3. **visible evidence**：agent 实际需要看到的内容，而不是命令真实产生的全部内容。
4. **full evidence retained**：可见输出减少不等于证据丢失；完整日志必须还能回取。

一个保守的估算可以这样做：

```sh
raw_bytes=7200
visible_bytes=99

awk -v raw="$raw_bytes" -v shown="$visible_bytes" '
  BEGIN {
    saved = raw - shown
    reduction = saved * 100 / raw
    # A rough English/code CLI estimate. Do not use this as accounting-grade truth.
    estimated_tokens_saved = saved / 4
    printf "visible reduction: %.1f%%\n", reduction
    printf "rough tokens avoided: %.0f\n", estimated_tokens_saved
  }
'
```

这不是精算。它只是一个足够诚实的工程仪表盘：先防止 accidental context expansion，再决定是否值得做更细的 tokenizer 级测量。

## `cap`：不要让命令输出淹没会话

普通做法很常见：

```sh
cargo test 2>&1 | head -c 4000
```

这行命令的问题也很常见：exit code 容易被 pipeline 语义弄歪，stderr/stdout 太早混在一起，失败尾部可能丢失，完整证据没有保存，binary output 还可能把终端弄得像维多利亚时期的管道工程。

`cap` 的原则是：**屏幕有界，证据完整**。

```sh
cap --bytes 12000 -- cargo test
cap --focus error -- cargo check
cap --json -- npm test
```

它会保存完整日志，只展示 bounded view，并保留 wrapped command 的退出码。这样 agent 可以先看少量高价值输出；如果需要，再回取完整日志，而不是重跑一次 noisy command。

本地 self-host 样本里：

```text
raw command output: 7200 bytes
visible output:       99 bytes
visible reduction:    98%
rough tokens avoided: about 1,775 tokens
```

这不是说每个项目都会省 98%。这是说在“输出明显过量”的场景里，`cap` 可以把浪费挡在第一层。

## `span`：不要因为一行错误读完整文件

agent 最容易犯的低级错误之一，是看到：

```text
src/main.rs:360: ...
```

然后把整个 `src/main.rs` 读进上下文。几百行还好，几千行就开始变成昂贵的散文朗诵。

`span` 的做法是返回 containing unit：

```sh
span src/main.rs:360
span --contains "unwrap()" src
span --backend auto --explain --symbol run_command src
```

默认是 heuristic backend；如果装了 `ast-outline` 或 `ast-bro`，`--backend auto` 可以用它们做更强的提取，但仍然受 `--max-lines` 约束。也就是说，`span` 是 bounded context facade，不是 AST 工具的替代品。

本地 self-host 样本：

```text
full file:          1120 lines
span heuristic:       84 lines   -> 92% line reduction
span auto backend:    20 lines   -> 98% line reduction via ast-outline
```

如果按每行 50-80 个字符、每 4 个字符约 1 token 粗估，少读一千行代码通常就是少喂一万级别 token。这个估算不精确，但方向足够清楚：**上下文边界比 prompt 技巧更有用**。

## `fx`：命令改了什么，要有 receipt

很多 agent 会这样工作：

```sh
cargo fmt
cargo test
git diff
```

问题是 `git diff` 可能太大，`git status` 又不告诉你“这次命令”造成了什么。`fx` 把命令变成一个带文件效果 receipt 的动作：

```sh
fx --json -- cargo fmt
fx --watch-path crates/parser -- cargo test -p parser
```

它报告 created / modified / deleted，结合 Git tracked / untracked / ignored 分类，并总结 source files、lockfiles、ignored files 是否变化。

`fx` 不一定直接少打印很多 token。它更重要的是减少第二轮、第三轮的侦探工作：

```text
Did this touch source?
Did it modify Cargo.lock?
Was that only target/ cache?
Did a generator create fixtures?
```

少问这些问题，才是真正的 context saving。不是每次都立刻少几千 token，但能少掉很多“让我看看还有什么变了”的盲目扩张。

## `tap`：看管道，不要拆管道

pipeline 调试常见的坏习惯：

```sh
producer > /tmp/a
head /tmp/a
wc -l /tmp/a
filter < /tmp/a > /tmp/b
head /tmp/b
```

这会产生临时文件、改变工作流，还经常把样本 dump 进上下文。`tap` 的原则是：**stdout byte-for-byte pass-through，观察信息写 stderr**。

```sh
cat events.jsonl \
  | tap --label raw --json-shape \
  | jq '.level' \
  | tap --label levels
```

你能看到 bytes、lines、throughput、sample、binary detection、JSONL field shape，同时下游收到的数据不变。

在本地 community benchmark 里：

```text
tap pipeline: 90 bytes in, 90 bytes out, pass-through ok
```

这里的收益不是“压缩了 90 bytes”。收益是避免为了理解 stream shape 而把中间数据摊满屏幕。厨房可以有窗，但不必把整锅汤倒在地毯上。

## 一组可复现的本地测量

当前 checkout 的本地 benchmark 结果如下：

```text
Generated: 2026-05-27T03:10:18Z

cap noisy output:      15600 bytes -> 139 bytes, 99% visible reduction
span heuristic:         1120 lines -> 84 lines, 92% line reduction
span auto:              1120 lines -> 30 lines, 97% line reduction via ast-outline
fx file effects:        2 effects, source + lockfile summary ok
tap pipeline:           stdout pass-through ok
```

复现命令：

```sh
sh scripts/self-host-check.sh
sh scripts/community-benchmark.sh
sed -n '1,120p' reports/community/latest.md
```

这些数字只说明这套工具在这个 repo、这些样本上有效。它们不应该被包装成普适生产力百分比。更稳妥的说法是：

> 在 noisy command 和 over-broad source inspection 场景里，本地样本显示可见上下文减少约 90%+；在真实 agent 开发会话里，整体减少 50-85% accidental context expansion 是一个谨慎但可期待的区间，具体取决于工作流。

如果一个会话本来就只跑短命令、读小文件，这套工具不会神奇地节省什么。它最多让你显得更有纪律，当然这在软件工程里已经相当罕见。

## 我会怎样用它们

我的默认规则很简单：

```text
1. 输出未知或可能很大的命令，用 cap。
2. 已知 file:line / symbol / pattern 时，用 span，不先 cat 整文件。
3. 可能改文件的命令，用 fx 包起来。
4. pipeline 调试用 tap，不 dump 中间文件。
5. 要做宽范围 mutation 时，未来用 tx；现在至少先用 fx 看清楚效果。
```

组合起来像这样：

```sh
rg -n "run_command" cap/src cap/tests
span --backend auto --explain cap/src/main.rs:250

cap --focus error -- cargo test
fx --json -- cargo fmt

cat reports/community/latest.json \
  | tap --label report --json-shape \
  | jq '.scenarios.cap_noisy_output'
```

这套东西的价值不在“替代 shell”。恰恰相反，它尊重 shell。它只是承认现代 terminal work 已经从：

```text
command -> output
```

变成了：

```text
intent -> command -> observation -> decision -> mutation -> verification
```

如果这个循环里每一步都无界，agent 就会浪费上下文，人类就会浪费耐心。两者都很贵，只是人类通常收费更高。

## 最后：不要崇拜 token

Token 是账单单位，不是工程目标。真正的目标是：

- 少看无关输出；
- 少读无关代码；
- 更快知道命令造成了什么；
- 调试数据流时不破坏数据流；
- 保留足够证据，能复查，而不是凭感觉。

所以我更愿意把这套工具叫：

```text
bounded terminal primitives
```

而不是：

```text
AI productivity toolkit
```

前者像工具，后者像会议室里的贴纸。我们已经有太多贴纸了。
