# Quality Gates — RetypoAir

Implements the `apply-quality-gates` skill (`.claude/skills/apply-quality-gates/SKILL.md`),
adapted from CodeMiner42's *"Stop Reading AI Code, Start Measuring It"* playbook.

## Run it

```bash
bin/quality          # gate: run, compare to baseline, exit 0/1
bin/quality-bump     # re-capture baseline after deliberate improvement
```

Output writes to `tmp/quality/` (gitignored).

## Active gates

| Metric                         | Tool       | Threshold (per fn/file) | Baseline |
|---                             |---         |---                      |---:      |
| Cyclomatic complexity          | SwiftLint  | ≤ 6                     | 9        |
| Function body length           | SwiftLint  | ≤ 15 lines              | 35       |
| Type body length               | SwiftLint  | ≤ 100 lines             | 8        |
| File length                    | SwiftLint  | ≤ 100 lines (200 hard)  | 13       |
| Function parameter count       | SwiftLint  | ≤ 4                     | 0 ✓      |
| Force unwrapping               | SwiftLint  | none                    | 0 ✓      |
| SwiftLint total warnings       | SwiftLint  | (ratchet only)          | 72       |
| Unused declarations            | Periphery  | none                    | 4        |

### History

| Date       | force_unw | params | cyclomatic | fn_body | file_len | type_body | periphery |
|---         |---:       |---:    |---:        |---:     |---:      |---:       |---:       |
| 2026-05-06 (initial) | 5 | 4 | 10 | 36 | 10 | 8 | 29 |
| 2026-05-06 (after cleanup) | **0** | **0** | 9 | 35 | 13 ↑ | 8 | **4** |

`file_length` rose 10→13 because splitting `AppState.swift` (853 LOC) into 7 focused
files added new files between 100–200 lines each. Net code organization improved;
the metric is a poor proxy in this case. Next sprint should target the remaining
oversized files: `RetypoView.swift` (1050), `AppDelegate.swift` (367),
`NativeTextEditor.swift` (329).

The numbers above are *current violation counts*. The gate passes if a PR does
not increase any count. Use `bin/quality-bump` to commit a new lower baseline
after improvements. SwiftLint per-rule thresholds are in `.swiftlint.yml`.

## Skipped gates (honest)

| Metric                  | Why skipped                                                                 |
|---                      |---                                                                          |
| Line coverage           | No test target exists yet. Add one, then re-enable via xcov/Slather.       |
| Branch coverage         | Apple platforms only expose line coverage natively. Mutation compensates.  |
| Mutation kill ratio     | Blocked on a test target. Plan: introduce **Muter** once tests exist.      |
| Dependency structure    | Single SPM target — splitting is architecture-theatre at this scale.       |

These will be revisited when (a) a `Tests/` target is added, or (b) the project
grows past one SPM module.

## How to improve a metric

1. Run `bin/quality` to see which gate(s) are currently the worst offenders.
2. Open the SwiftLint report (`swiftlint lint`) — fix top hits.
3. Re-run `bin/quality`. If counts dropped, run `bin/quality-bump` to lock in.
4. Commit `quality_thresholds.json` alongside the code changes.

Pick *one* metric to actively improve per PR; let the others just hold steady.

## CI / hooks

Not yet wired. Once the gate has held for ~a week of normal commits, add to
`.git/hooks/pre-push`:

```bash
#!/usr/bin/env bash
exec bin/quality
```
