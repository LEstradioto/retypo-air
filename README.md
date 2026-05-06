# Retypo Air

Tiny macOS floating text box for drafting agent prompts, correcting typos with an LLM, and copying the result to the clipboard.

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

- `Cmd+Shift+Space`: show/hide the floating panel.
- `Enter`: correct current text and copy result.
- `Shift+Enter`: insert a new line.
- `Esc`: hide the panel.
- Auto mode: after you stop typing for 500ms, Retypo corrects and copies automatically.
- Auto off: Retypo only runs when you press Enter or click a button.

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

## Editing actions

Buttons included:

- Correct
- Improve
- Translate
- Simplify
- Summarize
- Bullets

The result is shown in the lower preview area and copied if `Auto copy` is enabled.
