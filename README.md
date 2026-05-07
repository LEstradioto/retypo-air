# Retypo Air

A tiny macOS floating textbox for easy run pre-configured prompts to fix the text you select from any app (or manual input) and auto-clipboard the polished output.

> [!IMPORTANT]
> **This is a personal opiniated 100% AI-assisted. Use at your own risk.**
>
> I built it to me: global shortcut > small textbox > snappy navigation > use prompts > result to clipboard. That's it.
>
> macOS-only. No `.app` installer or signing, run the dev script yourself. Local-first: settings, drafts, history, and API keys live under `~/.retypo-air/`. No telemetry.

## Caveats

- macOS 13+, Swift 5.9+, Xcode CLT or Xcode.
- The selected-text import feature (`Cmd+Shift+Enter` while another app is focused) needs macOS Accessibility permission, grant it once when prompted (you should select the generated RetypoAir-dev.app at the ./build-dev folder)
- Bring your own API key, at least one of Groq, Anthropic, OpenAI, or OpenRouter.

## Quick start

```bash
cp .env.example .env       # add at least one *_API_KEY - Loaded in this order (first wins): existing shell env → `.env` in CWD → `~/.retypo-air/.env`.
scripts/dev-app.sh         # builds + opens build-dev/RetypoAir-dev.app
```

In Settings, pick a provider and click **Refresh** to load its model list. Be unstoppable!

## Keyboard

| Shortcut | Action |
| --- | --- |
| `Cmd+Shift+Space` | Show / hide the panel (global). When triggered from another app, also imports its selection / clipboard |
| `Cmd+Shift+Enter` | Run all enabled modes against the current draft (Retypo focused) |
| `Enter` | Run current mode (auto-copies result) |
| `Shift+Enter` | New line |
| `Esc` | Hide panel |
| `Cmd+D` | Toggle Candidates overlay |
| `Cmd+S` | Toggle Settings |
| `Ctrl+Tab` | Cycle focus between editor and footer |
| `Tab` / `Shift+Tab` / `←` / `→` | Navigate within footer / Candidates / Settings |
| `Cmd+1`…`Cmd+0` | Pick a mode (default bindings; editable) |
| `Cmd+Opt+]` / `Cmd+Opt+[` | Cycle accepted models |
| `Cmd+C/V/X/A`, `Cmd+Z`, `Shift+Cmd+Z` | Standard editing |
| `Option+←/→`, `Shift+Option+←/→` | Move / select by word |
| `Home` / `End` (+ `Cmd` for document) | Line / document boundaries |
| `Ctrl+U` / `Ctrl+K` / `Ctrl+Y` | Kill to line start / end / yank |
| `Cmd+Q` | Quit |

`Cmd+Shift+Space` is not Spotlight (`Cmd+Space`) or the emoji viewer (`Ctrl+Cmd+Space`); a few apps may bind it but it's generally safe.

## Modes / Templates

Modes are just saved prompt Templates, for reuse. And Freeform is to manual input.

Built-in: Correct, Typos & Grammar, Improve Writing, Translate, Simplify, Summarize, Bullets, Better way of saying, Make this Tweet Fit, Generate 3 variations, How to respond 3 ways, Caveman, **Freeform**.

## Features

- Selected-text import
- Toggle Mode window (`Cmd+D`), select Prompt Templates with arrows, Enter to run
- Inline Diff highlighting editted text
- two themes Glass, Lighter (almost transparent)
- Show on active screen bottom optional
- Save/restore history
- Cost by session/day stats
- WPM and Chars Count stats
- Undo/Redo
- Prompt Templates

## Files (`~/.retypo-air/`)

| File | Purpose |
| --- | --- |
| `settings.json` | App preferences |
| `modes.json` | Editable modes / prompts |
| `pricing.json` | USD per 1M tokens (editable) |
| `history.json` | LLM run history (incl. the actual prompt sent) |
| `usage-ledger.json` | Token / cost ledger |
| `draft.txt` | Realtime draft recovery |
| `draft-history.json` | Draft snapshots |
| `import-debug.log` | Selection-import diagnostics |

## Selected-text import precedence

1. **Live selection** via the Accessibility API (works in native macOS apps; no clipboard touched).
2. **Synthetic `Cmd+C`** via the AX-pressed Copy menu, then the clipboard is read and restored (works in terminals / TUIs that expose copy).
3. **Existing clipboard contents** — whatever you already had copied.

If a draft already exists, Retypo asks before replacing. If everything fails, check `~/.retypo-air/import-debug.log`.

## Contribution / Quality gates

Contributions are welcome, be aware of quality gates

Pre-push hook runs `bin/quality` — SwiftLint + Periphery + tests + coverage gate, all ratcheted from `quality_thresholds.json`. See `QUALITY.md` for what's measured and the playbook this follows.

```bash
bin/quality          # run all gates
bin/quality-bump     # ratchet baseline lower after improvements
swift test           # tests only
```
