# Retypo Air

A tiny macOS floating textbox for easy run pre-configured prompts to fix the text you select from any app (or manual input) and auto-clipboard the polished output.

> [!IMPORTANT]
> **Personal, opinionated, 100% AI-assisted. Use at your own risk.**
>
> I built it for me: global shortcut → small textbox → snappy navigation → use prompts → result to clipboard. That's it.
>
> macOS-only. No `.app` installer or signing — run the dev script yourself. Local-first: settings, drafts, history, and API keys live under `~/.retypo-air/`. No telemetry.

## Caveats

- macOS 13+, Swift 5.9+, Xcode CLT or Xcode.
- The selected-text import feature (`Cmd+Shift+Space` while another app is focused) needs macOS Accessibility permission. Grant it once when prompted, selecting the generated `build-dev/RetypoAir-dev.app`.
- Bring your own API key — at least one of Groq, Anthropic, OpenAI, or OpenRouter.

## Quick start

```bash
cp .env.example .env       # add at least one *_API_KEY (loaded shell env → .env in CWD → ~/.retypo-air/.env, first wins)
scripts/dev-app.sh         # builds + opens build-dev/RetypoAir-dev.app
```

In Settings, pick a provider and click **Refresh** to load its model list. Be unstoppable!

## Keyboard

| Shortcut | Action |
| --- | --- |
| `Cmd+Shift+Space` | Show / hide the panel (global). From another app, also pulls in its selection / clipboard |
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

## Modes (saved prompt templates)

A *mode* is just a saved system prompt the LLM is given before your text. **Freeform** is special: you type the prompt live each run (popup opens on Enter, type, Enter again to apply).

Built-in: Correct, Typos & Grammar, Improve Writing, Translate, Simplify, Summarize, Bullets, Better way of saying, Make this Tweet Fit, Generate 3 variations, How to respond 3 ways, Caveman, **Freeform**.

Edit / rename / disable / shortcut-bind any mode in Settings. Stored in `~/.retypo-air/modes.json`.

## Selected-text import precedence

When you trigger `Cmd+Shift+Space` from another app:

1. **Live selection** via the Accessibility API — fast, doesn't touch the clipboard. Works in native macOS apps.
2. **Synthetic `Cmd+C`** via the AX-pressed Copy menu — clipboard is read then restored. Covers terminals / TUIs that expose copy.
3. **Existing clipboard contents** — whatever you already had copied.

If a draft already exists, Retypo asks before replacing. Failure log: `~/.retypo-air/import-debug.log`.

## Features

- Multi-provider: Groq, Anthropic, OpenAI, OpenRouter. Models discovered via each provider's API, then cached.
- **Candidates overlay** (`Cmd+D`): mode picker when empty (arrows + Enter to run any mode without replacing the draft); after `Cmd+Shift+Enter`, browse all enabled-mode outputs side-by-side and apply one with Enter.
- **Inline diff** layout: result replaces input; changed words underlined in subtle green (word-level LCS). Optional **Stacked** layout shows input above, result/diff below.
- Two themes: **Glass** (default) and **Lighter** (mostly transparent).
- Optional *Show on active screen bottom*: `Cmd+Shift+Space` centers the panel near the cursor's screen.
- **Per-mode and per-model shortcuts**, configurable in Settings.
- **History** of every run (input, output, diff, model, instruction, tokens, cost) — limit 10 / 50 / 200, restorable from Settings.
- **Cost tracking**: last / session / today USD, computed from provider-reported tokens × editable per-model pricing.
- **Live stats** in the footer: WPM (with warm-up + pause-reset), changed-word delta, character count, status.
- **Auto-save drafts** with realtime recovery + snapshot history. Undo/redo with `Cmd+Z` / `Shift+Cmd+Z`.
- **Auto-copy** the result on each run (toggleable). Optional **hide-after-copy** for one-and-done flows.

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

## Contribution / Quality gates

Contributions are welcome — be aware of the quality gates.

Pre-push hook runs `bin/quality` — SwiftLint + Periphery + tests + coverage, all ratcheted from `quality_thresholds.json`. See `QUALITY.md` for the playbook.

```bash
bin/quality          # run all gates
bin/quality-bump     # ratchet baseline lower after improvements
swift test           # tests only
```
