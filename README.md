# Retypo Air

Tiny macOS floating text box for drafting agent prompts, correcting typos with an LLM, and copying the result to the clipboard.

## Build a dev .app

For features that send keyboard events to another app, run Retypo as a real `.app` bundle so macOS can grant stable Accessibility permission:

```bash
scripts/dev-app.sh
```

Then open System Settings → Privacy & Security → Accessibility and enable **Retypo Air Dev**. The dev bundle is created at `build-dev/RetypoAir-dev.app`.

### Quit/reload dev app

Use `Cmd+Q` while Retypo Air is focused, or run:

```bash
osascript -e 'tell application id "app.retypoair.dev" to quit'
```

Then rerun `scripts/dev-app.sh`.

## Run

Set at least one API key. Default provider is Groq.

```bash
cp .env.example .env
# edit .env and add GROQ_API_KEY or another provider key
swift run --disable-sandbox RetypoAir
```

You can also use shell environment variables directly:

```bash
export GROQ_API_KEY="..."
swift run --disable-sandbox RetypoAir
```

If your local SwiftPM does not need the flag, this also works:

```bash
swift run RetypoAir
```

## Behavior

- `Cmd+Shift+Space`: show/hide the floating panel and focus the editor.
- `Cmd+Shift+Enter`: when another app is focused, experimentally import its selected text into Retypo.
- `Enter`: run the current mode and copy result.
- `Shift+Enter`: insert a new line.
- `Esc`: hide the panel.
- `Home` / `End`: move to beginning/end of the current line.
- `Cmd+Home` / `Cmd+End` or `Ctrl+Home` / `Ctrl+End`: move to beginning/end of document.
- `Option+Left` / `Option+Right`: move by word.
- `Shift+Option+Left` / `Shift+Option+Right`: select by word.
- `Cmd+A` and `Ctrl+A`: select all text.
- `Cmd+C`, `Cmd+V`, `Cmd+X`: copy, paste, cut inside the editor.
- `Ctrl+U`: delete from cursor to beginning of line.
- `Ctrl+K`: delete from cursor to end of line.
- `Ctrl+Y`: yank back the last text killed by `Ctrl+U` / `Ctrl+K`.
- Auto mode: after you stop typing for 500ms, Retypo runs the current mode and copies automatically.
- Auto off: Retypo only runs when you press Enter.



### Debug selected-text import

If selected-text import does not work, try once and inspect:

```bash
tail -n 80 ~/.retypo-air/import-debug.log
```

Alternative experimental import hotkey: `Cmd+Option+Shift+I`.

## Experimental selected-text import

`Cmd+Shift+Enter` attempts to import the current selection from the frontmost app. Retypo temporarily sends `Cmd+C`, reads the clipboard, restores the previous clipboard contents, and opens the panel with the imported text.

This is exact when the source app exposes normal copy behavior. It works best when you manually select text first. If Retypo already has draft text, it asks before replacing it. Terminals and TUI apps may require macOS Accessibility permission for Retypo Air, and no text is imported if the app cannot copy the selection.

## Main panel modes

Retypo has two editor layouts, configured in Settings:

- **Stacked**: type on top, see the result/diff below.
- **Inline diff**: the result applies back into the textarea and changed text is highlighted.

Themes:

- **Glass**: default floating panel.
- **Lighter**: nearly transparent panel with only a subtle textarea surface.

The footer is clickable/minimal:

- mode label (`Correct`, `Summarize`, etc.) opens the mode menu;
- model label opens the model menu;
- `Stacked` / `Inline` toggles layout;
- `Auto` / `Manual` toggles auto-run.

## .env loading

Retypo Air automatically loads:

1. `.env` from the directory where you run `swift run`
2. `~/.retypo-air/.env`

Existing shell environment variables have priority over `.env` values.

## Providers

Supported providers:

- Groq: `GROQ_API_KEY`
- Anthropic: `ANTHROPIC_API_KEY`
- OpenAI: `OPENAI_API_KEY`
- OpenRouter: `OPENROUTER_API_KEY`

Click `Refresh` to load models from the selected provider, then choose a model manually.

## Settings

Settings are stored in:

```text
~/.retypo-air/settings.json
```

Current settings include:

- provider
- selected model per provider
- auto correct
- auto copy
- hide after copy
- always on top
- native macOS spellcheck
- debounce time
- panel size/position

## Modes / editing actions

Modes are configured in Settings. The selected mode is what `Enter` and Auto run.

Included modes:

- Correct
- Typos and Grammar
- Improve Writing
- Translate
- Simplify
- Summarize
- Bullets
- Better way of saying
- Make this Tweet Fit
- Generate 3 variations
- How to respond 3 ways
- Caveman

Default editor-focused shortcuts:

- `cmd+1`: Correct
- `cmd+2`: Improve Writing
- `cmd+3`: Translate
- `cmd+4`: Simplify
- `cmd+5`: Summarize
- `cmd+6`: Bullets
- `cmd+7`: Better way of saying
- `cmd+8`: Make this Tweet Fit
- `cmd+9`: Generate 3 variations
- `cmd+0`: How to respond 3 ways
- `cmd+opt+]`: next accepted model
- `cmd+opt+[`: previous accepted model

In Settings, check 2–3 accepted models from the loaded provider list. Next/previous model shortcuts only browse checked models; if none are checked, they browse all loaded models.

You can edit mode and model shortcuts in Settings. These shortcuts currently work while the Retypo editor is focused; the global show/hide shortcut is fixed at `cmd+shift+space`.

## Shortcut note

`Cmd+Shift+Space` is not macOS Spotlight (`Cmd+Space`) and not the default emoji/character viewer (`Ctrl+Cmd+Space`). Some individual apps may bind it, but it is usually safe as a lightweight global show/hide shortcut.

## Diff highlighting

Inline diff mode uses a word-level LCS diff over the original and corrected text, then highlights changed/inserted words in subtle green with an underline. This follows the VS Code idea of subtle inline character/word highlights instead of loud full-line coloring.

## Recovery, history, and cost

Retypo continuously saves the current draft to:

```text
~/.retypo-air/draft.txt
```

It also stores:

- last 10 LLM runs: `~/.retypo-air/history.json`
- usage ledger: `~/.retypo-air/usage-ledger.json`
- editable modes: `~/.retypo-air/modes.json`
- editable model pricing: `~/.retypo-air/pricing.json`

Cost labels use token usage returned by providers. To compute USD cost, set model pricing in Settings as USD per 1M input/output tokens. Without pricing, cost shows `$—`.

## Candidate overlay

- `Cmd+D`: toggle the floating candidate/diff window.
- `Cmd+S`: toggle the floating settings window.
- `Cmd+Shift+Enter`: while Retypo is focused, run all enabled modes against the current draft and show all candidates.
- `Tab`: while candidate window is open, cycles modes if no result exists yet; otherwise cycles candidates and copies the selected candidate to the clipboard.
- `Enter`: while candidate window is open with no result, runs the selected mode into the candidate window.
- `Apply`: replaces the editor draft with the selected candidate.

## Screen placement

If `Show on active screen bottom` is enabled, `Cmd+Shift+Space` positions Retypo centered near the bottom of the screen containing the mouse pointer, with width around one third of the visible screen. The app preserves your current height when moving across screens.

## Pricing defaults

Retypo includes seeded pricing for common OpenAI, Anthropic, and Groq text models, then stores editable prices in `~/.retypo-air/pricing.json`. OpenRouter model pricing is parsed from its model list when present. Pricing changes often; verify in provider docs if cost precision matters:

- OpenAI: https://platform.openai.com/docs/pricing
- Anthropic: https://docs.anthropic.com/en/docs/about-claude/pricing
- Groq: https://groq.com/pricing
- OpenRouter: https://openrouter.ai/docs/api-reference/list-available-models

The Settings and Candidates surfaces are separate floating windows. The candidate window appears directly above the main Retypo window, centered on the same screen and expanded near full screen width with compact height.

## History limit

Settings → History lets you choose how many LLM runs to save: 10, 50, or 200. The settings UI still shows the latest entries compactly; open `~/.retypo-air/history.json` directly for the full saved list.
