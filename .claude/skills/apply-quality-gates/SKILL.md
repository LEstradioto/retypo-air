---
name: apply-quality-gates
description: Apply the "measure AI code instead of reading it" playbook — set up automated quality gates (coverage, complexity, module size, mutation, dependency) with a ratcheted baseline. Use when the user asks to "set up quality gates", "measure AI code", "apply the codeminer42 playbook", "add a quality ratchet", or wants concrete metric thresholds and tooling for Ruby/Rails, Swift, or JavaScript/TypeScript.
---

# Apply Quality Gates

Adapted from CodeMiner42's *"Stop Reading AI Code, Start Measuring It"* (Rails playbook). Generalized to Ruby/Rails, Swift, and JavaScript/TypeScript.

## Philosophy (do not skip)

- Humans don't read all AI diffs anyway — metrics gate fitness so humans gate **architecture and intent**.
- **Ratchet, don't perfect.** Lock today's numbers as baseline. Any PR that worsens any metric fails. Improvements lower the baseline via a deliberate `bump` command.
- **Calibrate to reality.** Don't punish framework idioms with academic thresholds.
- **Honest exclusions beat tortured architecture.** A skipped metric, documented, > a fake gate.
- **No metric is sufficient alone.** Coverage proves *execution*; mutation proves *assertion*; complexity prevents *sprawl*; ratchet prevents *regression*.

## The Five Metrics

### 1. Test coverage (line + branch)
- **Line ≥ 95%**, **Branch ≥ 90%** as starting targets — ratchet from initial run if lower.
- Exclude: tests, generated code, migrations/schema, config, vendored.
- Necessary but insufficient — a line ran ≠ behavior was asserted.

### 2. Cyclomatic complexity & method size
- **Cyclomatic ≤ 6** per function (each `if`/`case`/`&&`/`rescue`/`guard` adds 1).
- **Perceived/cognitive ≤ 7** where the tool supports it.
- **Method/function length ≤ 15 lines.**
- **Parameter count ≤ 4.**
- ABC-style score (Ruby Flog) — method ≤ 20, class ≤ 70 if available.
- Exclude: tests, migrations.

### 3. Module / file size (SRP proxy)
- **Class/file ≤ 100 lines** (excluding specs, migrations, generated).
- Cheapest signal that a class has multiple reasons to change. Cannot prove SRP, but holds the line.

### 4. Mutation testing (kill ratio)
- Tests pass → tool mutates code (`>` → `>=`, `true` → `false`, drop `.save!`, negate condition) → re-run tests.
- **Kill ratio = killed / total mutations.** Catches tests that exercise without asserting.
- **Ratchet from first run** — no fixed minimum. Rule: "don't get worse." Typical baselines land 60–75%.
- Expensive (long runs); gate behind reasonable line coverage and run nightly or on demand if too slow for pre-push.

### 5. Dependency structure (architecture)
- No cycles. High-level modules don't import low-level. Layer rules respected.
- **Skip honestly** if the project is too small (e.g. <10 modules). Document and revisit at scale.

### What this approach does NOT catch
Security (SQLi, XSS), performance (N+1, slow paths), concurrency/races, memory leaks, idiomatic fit, **intent** (was the right feature built?). These still require human/specialized review.

## The Ratchet Mechanism

```
quality_thresholds.<yml|json>   # baselines, committed
bin/quality                     # one command, runs all gates
bin/quality:bump                # lower thresholds after improvement (deliberate)
```

- Each sub-tool writes a small machine-readable artifact (JSON) to `tmp/quality/`.
- A single aggregator reads them, compares to baseline, prints a table, exits 0/1.
- Wired into **pre-push hook** and/or **CI**. Mutation may be moved to nightly if slow.
- ESLint/SwiftLint emit **warn**, never **error** during dev — the gate is the *count diff*, not per-rule fail.
- Document the rule in `CLAUDE.md` / `AGENTS.md`: *"Run `bin/quality` before declaring work complete; report numbers in your final message."*

## Per-Language Tooling

### Ruby / Rails
| Metric | Tool | Notes |
|---|---|---|
| Coverage (line + branch) | **SimpleCov** with `enable_coverage :branch` | Reads `coverage/.last_run.json`. |
| Cyclomatic / method / class size / params | **RuboCop** Metrics cops | `Metrics/CyclomaticComplexity` 6, `PerceivedComplexity` 7, `MethodLength` 15, `AbcSize` 15, `ClassLength` 100, `ParameterLists` 4. |
| ABC complexity | **Flog** gem | Method max 20, class max 70. Splat the paths (`Flog.new.flog(*paths)`) — iterating resets state. |
| Mutation testing | **Mutant** (mbj/mutant) + RSpec | Free for OSS, paid for private (~$30/mo or $250/yr per dev). Needs Rails eager-loaded before subject discovery. |
| Dependency structure | **Packwerk** (Shopify) | Skip below ~40 controllers — architecture-theatre otherwise. |
| Style | **rubocop-rails-omakase** | Defaults sane; override Metrics cops as above. |

### Swift (iOS / macOS / tvOS / watchOS)
| Metric | Tool | Notes |
|---|---|---|
| Coverage (line; no native branch) | **Xcode** native (`xcodebuild test -enableCodeCoverage YES`) parsed by **xcov** or **Slather** | No first-class branch coverage on Apple platforms — use line + mutation to compensate. Slather emits Cobertura/JSON; xcov emits HTML/JSON/Markdown. Configure exclusions via `.slather.yml` or `xcov` flags (`--include_targets`, regex ignores for `*View.swift`, generated, etc.). |
| Cyclomatic / function / type / file / params | **SwiftLint** | Built-in rules: `cyclomatic_complexity` (warning 6, error 10), `function_body_length` (15), `type_body_length` (100), `file_length` (100/200), `function_parameter_count` (4). Set `severity: warning` so dev never blocks; gate on count-diff. |
| Mutation testing | **Muter** (`muter-mutation-testing/muter`) | Actively maintained (last release Nov 2025). Operators: RelationalOperatorReplacement, RemoveSideEffects, ChangeLogicalConnector, SwapTernary, etc. Works with any `xcodebuild`-buildable target. Run from project root; outputs JSON. **Slow** — usually nightly/on-demand, not pre-push. |
| Dead code / unused symbols | **Periphery** (`peripheryapp/periphery`) | SourceKit-indexed unused class/struct/protocol/func/property/enum/typealias detection. Pass `--retain-objc-accessible` for mixed Swift/ObjC targets to avoid false positives. Strong replacement for what Rubocop's `Lint/UselessAssignment` doesn't reach. |
| Static analysis (memory / API misuse) | **`xcodebuild analyze`** (Clang Static Analyzer) | Free, built in. Catches a class of nil/leak/over-release issues. |
| Dependency structure | **SPM module graph** (`swift package describe --type json`) + manual target boundaries | No Packwerk equivalent. Enforce by splitting into SPM targets so `import X` is a compile-time gate. For cycle detection in source-level imports, parse `swift package show-dependencies` or use [SwiftGraph](https://github.com/davecom/SwiftGraph) on a custom import scan. **Skip honestly** for small apps. |
| Style / format | **swift-format** (Apple) or **SwiftLint --fix** | Pick one; don't run both. |

Notes specific to Swift:
- **No branch coverage natively** — mutation testing matters more here than in Ruby/JS to compensate.
- SwiftLint thresholds are split into `warning` and `error`; for the ratchet pattern, set both to the *same* value as `warning` and never use `error` (count-diff gates the build, not the lint itself).
- For iOS apps with a lot of SwiftUI `View` files, exclude `*View.swift` from coverage *and* file-length checks, or budget separately — declarative UI inflates LOC without inflating logic.

### JavaScript / TypeScript
| Metric | Tool | Notes |
|---|---|---|
| Coverage (line + branch) | **c8** / **v8 coverage** (Node 14+) or framework-built-in: `vitest --coverage`, `jest --coverage`, `bun test --coverage` | All emit `coverage/coverage-summary.json` (Istanbul format). Same line ≥ 95 / branch ≥ 90 starting targets. |
| Cyclomatic / function / file / params | **ESLint** built-ins | `complexity: ["warn", 6]`, `max-lines: ["warn", 100]`, `max-lines-per-function: ["warn", 15]`, `max-params: ["warn", 4]`, `max-depth: ["warn", 3]`. Test files excluded via overrides. |
| Cognitive complexity | **eslint-plugin-sonarjs** `cognitive-complexity` (≤ 7) | Better signal than cyclomatic alone — correlates with bug density. |
| Per-file complexity report | **eslintcc** | Standalone CLI for diff-friendly numbers. |
| Mutation testing | **StrykerJS** (`@stryker-mutator/core`) | Mature, supports vitest/jest/mocha. Run nightly; ratchet kill ratio. |
| Dependency cycles | **madge** | `madge --circular --extensions ts,tsx src/` — fail on any. |
| Module/layer boundaries | **dependency-cruiser** | Rule-based: forbid `app → lib`-style violations. More expressive than madge. |
| Import-level cycle/order rules | **eslint-plugin-import** (`no-cycle`, `no-restricted-paths`) | Lighter alternative for inside-module rules. |
| Dead code / unused exports | **knip** (preferred) or **ts-prune** / **unimported** | Knip handles monorepos, dynamic imports, framework entrypoints. |
| Type strictness | `tsc --strict` + `noUncheckedIndexedAccess` | Track `any`/`unknown`/`@ts-ignore` count as a ratcheted metric. |
| Style / format | **Prettier** + **eslint-config-prettier** | Don't fight the formatter. |

## Implementation Pattern (any language)

```
quality_thresholds.{yml,json}   # committed baseline
tmp/quality/<tool>.json         # per-tool measurement (gitignored)
bin/quality                     # orchestrator: run, parse, compare, exit
bin/quality:bump                # rewrite baseline after deliberate improvement
```

Steps:
1. Run each tool, write a tiny JSON `{ measure: <number> }` artifact.
2. Aggregator loads thresholds + artifacts, prints a table:
   ```
   Line coverage         96.6%   >= 95.0%   ✓
   Branch coverage       91.1%   >= 90.0%   ✓
   Cyclomatic max        7       <= 6        ✗
   Mutation kill ratio   69.6%   >= 69.5%   ✓
   ```
3. Exit non-zero on any fail.
4. **Hook in pre-push**, not pre-commit (commits stay fast). CI re-runs the same `bin/quality`.
5. Move expensive gates (mutation, sometimes coverage on large suites) to nightly if pre-push exceeds ~60s.
6. Document in `CLAUDE.md` / `AGENTS.md`: AI must run `bin/quality` and report the table in its final message.

## Behavioral effect

- AI agents pre-empt failures: write tests alongside code, keep functions short.
- Regressions become concrete numbers, not vague taste arguments.
- Human review shifts from mechanical (now automated) to architecture and product intent.

## Bootstrapping a new repo

1. **Survey first** — run each tool in *report-only* mode and capture today's numbers.
2. Write those numbers as the initial baseline. Don't aim for 95/90 from day one.
3. Pick *one* metric to actively improve per sprint; the others just hold.
4. Add the gate to pre-push *only after* it's stable for a week locally.
5. Mutation testing comes **last** — only meaningful once coverage is healthy.

## When to skip a metric

- Coverage on pure-UI files (SwiftUI views, React presentational components): exclude or carve a separate, lower budget.
- Mutation on prototype/spike code: skip; introduce on stabilization.
- Dependency rules on small monoliths: skip. Revisit at module count ≥ 10–40.
- Class length on framework-mandated structures (Rails controllers with many actions, ViewModels): raise ceiling deliberately, document why.

## References

- [CodeMiner42 — Stop Reading AI Code, Start Measuring It](https://blog.codeminer42.com/stop-reading-ai-code-start-measuring-it-a-rails-playbook/)
- SwiftLint: https://realm.github.io/SwiftLint/cyclomatic_complexity.html
- Muter: https://github.com/muter-mutation-testing/muter
- Periphery: https://github.com/peripheryapp/periphery
- xcov / Slather: https://github.com/nakiostudio/xcov · https://github.com/SlatherOrg/slather
- StrykerJS: https://stryker-mutator.io/docs/stryker-js/introduction/
- madge: https://github.com/pahen/madge
- dependency-cruiser: https://github.com/sverweij/dependency-cruiser
- knip: https://knip.dev/
- Mutant (Ruby): https://github.com/mbj/mutant
- Packwerk: https://github.com/Shopify/packwerk
