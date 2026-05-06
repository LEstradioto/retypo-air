# Retypo Air

Retypo Air is a tiny macOS floating editor for writing prompts, fixing rough typing, comparing edits, and copying polished text without leaving your current workflow.

It is designed for terminal-based agent harnesses like Claude Code and Codex, but works anywhere you need a fast scratch box backed by LLM editing modes.

## Features

- Floating, always-on-top macOS panel with compact glass UI.
- Auto-correct after a typing pause, or manual correction with `Enter`.
- Multiple editing modes: correct, improve, translate, simplify, summarize, bullets, and custom modes.
- Provider support for Groq, Anthropic, OpenAI, and OpenRouter.
- Model discovery from provider APIs and accepted-model shortcuts.
- Stacked editor and inline-diff editor layouts.
- Candidate window for running one mode or all enabled modes and choosing the best result.
- Settings window with keyboard navigation, custom mode prompts, pricing, history, and recovery.
- Clipboard-first workflow: corrected text can be copied automatically.
- Draft recovery, LLM run history, token usage, and cost tracking.

> [!NOTE]
> Retypo Air currently runs as a Swift Package executable. Packaging as a signed `.app` bundle is intentionally left for later.

## Requirements

- macOS 13 or newer
- Xcode Command Line Tools or Xcode
- Swift 5.9+
- At least one provider API key

## Quick start

```bash
cp .env.example .env
# edit .env and add at least one API key
swift run --disable-sandbox RetypoAir
```

If your SwiftPM setup does not require sandbox disabling:

```bash
swift run RetypoAir
```

## API keys

Retypo Air loads environment variables from:

1. `.env` in the directory where you run the app
2. `~/.retypo-air/.env`
3. your existing shell environment

Shell environment variables take precedence over `.env` values.

Supported keys:

```bash
GROQ_API_KEY=
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
OPENROUTER_API_KEY=
```

## Core workflow

1. Open Retypo Air with `Cmd+Shift+Space`.
2. Type rough text in the editor.
3. Press `Enter` to run the current mode, or enable Auto mode to run after the debounce delay.
4. Paste the copied result into your terminal, editor, chat, or browser.

The footer exposes the current mode, model, layout, auto/manual state, settings, diff/candidates, last cost, session cost, WPM, delta words, status, and character count.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `Cmd+Shift+Space` | Show/hide the main panel |
| `Enter` | Run current mode and copy result |
| `Shift+Enter` | New line |
| `Cmd+Shift+Enter` | Run all enabled modes into Candidates |
| `Cmd+D` | Toggle Candidates |
| `Cmd+S` | Toggle/close Settings |
| `Esc` | Hide main panel |
| `Ctrl+Tab` | Move focus from editor to footer |
| `Tab` / `Shift+Tab` | Navigate footer, Settings, or Candidates when in focus mode |
| `Ctrl+U` | Kill from cursor to line start |
| `Ctrl+K` | Kill from cursor to line end |
| `Ctrl+Y` | Yank last killed text |
| `Cmd+C/V/X` | Copy, paste, cut inside editor |
| `Option+Arrow` | Move by word |
| `Shift+Option+Arrow` | Select by word |

## Editing modes

Built-in modes:

- Correct
- Improve
- Translate
- Simplify
- Summarize
- Bullets

Modes are editable in Settings. You can add, rename, delete, enable/disable, and assign shortcuts to modes. The prompt text is stored in:

```text
~/.retypo-air/modes.json
```

## Models and providers

Use Settings to select the provider, refresh its model list, choose a model, and check the accepted models you want keyboard browsing to use.

If accepted models are configured, next/previous model shortcuts only cycle through those models. If none are configured, they cycle through all loaded models.

## Candidates window

The Candidates window is a separate floating panel above the main editor.

Use it to:

- run one selected mode without replacing the current draft;
- run all enabled modes at once;
- compare outputs and diffs;
- copy/select candidates with `Tab`;
- apply a candidate back into the editor.

## History, recovery, and pricing

Retypo Air stores local state under:

```text
~/.retypo-air/
```

Important files:

| File | Purpose |
| --- | --- |
| `settings.json` | App preferences |
| `modes.json` | Editable modes and prompts |
| `pricing.json` | Editable USD-per-1M token pricing |
| `history.json` | Saved LLM runs |
| `usage-ledger.json` | Token/cost usage ledger |
| `draft.txt` | Realtime draft recovery |
| `draft-history.json` | Recent draft snapshots |

Cost tracking uses token usage returned by providers. If pricing is missing for a model, cost displays as `$—`.

## Project structure

```text
Sources/RetypoAir/
  AppDelegate.swift          macOS app lifecycle and global hotkey wiring
  AppState.swift             shared state, LLM flow, history, usage, settings actions
  RetypoView.swift           main UI and Settings UI
  CandidateWindowView.swift  Candidates floating window
  AuxiliaryPanels.swift      Settings/Candidates panel management
  FloatingPanel.swift        borderless main floating panel
  FocusRing.swift            manual focus/highlight coordinator
  MacOS/                     native editor, settings store, shortcut formatting
  LLM/                       provider clients and model discovery
  Editing/                   editing mode definitions
```

## Development

Build:

```bash
swift build --disable-sandbox
```

Run:

```bash
swift run --disable-sandbox RetypoAir
```

The app is intentionally local-first. User text, settings, history, pricing, and drafts are stored on disk in `~/.retypo-air/`.
