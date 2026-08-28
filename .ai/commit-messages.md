# Commit Message Instructions

Before generating, suggesting, or reviewing a commit message, inspect the actual changed scope and read this file in the current turn. Do not rely on remembered conventions.

Return exactly one plain-text line when the user asks only for a commit message: no body, bullets, quotes, code fences, labels, explanation, or trailing period.

Use:

```text
<subject>: <short summary>
```

Keep the complete line at or below 72 characters. Describe durable repository behavior without issue numbers, pull-request numbers, or temporary phase/stage labels.

## Subject selection

Use the narrowest meaningful subject:

- one function: the function name, for example `dowload_and_load(): validate failed downloads`
- one script/import: its stable file stem or import name, for example `sPlot import: preserve tagged artifact filename`
- one producer contract: the domain, for example `Trait data: preserve BIEN output partitions`
- database/schema integration: `database` or the affected table/domain
- website or README: `docs`
- tests or validation-only work: `tests`
- agent guidance: `agents`
- dependencies: `renv`
- editor configuration: `vscode`

For changes spanning repositories, propose one message per Git repository; never combine six repositories into one commit message.

## Wording

Start the summary with a specific verb such as `add`, `adjust`, `correct`, `document`, `preserve`, `remove`, `replace`, `split`, `switch`, `update`, or `validate`.

Do not use vague Conventional Commit labels or words such as `feat`, `feature`, `fix`, or `enhance`. State what changed.

Examples:

- `agents: add portable suite instruction routing`
- `database: validate producer keys before SQLite writes`
- `FOSSILPOL import: preserve age-uncertainty partitions`
- `docs: clarify released schema synchronization`
