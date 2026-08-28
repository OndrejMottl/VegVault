# VegVault Quarto and Documentation Guidance

Apply this guide to `README.qmd`, website `.qmd` sources, `_quarto.yml`, JSON theme inputs, SCSS, generated Markdown, and `docs/`.

## Source and generated files

- `README.qmd` is the source for `README.md`; edit the QMD and regenerate the Markdown.
- `_quarto.yml` configures a website whose rendered output is `docs/` and whose pre-render step is `R/04_Webiste/generate_theme.R`.
- Edit `.qmd`, `colors.json`, `fonts.json`, SCSS sources, and supporting R code rather than patching generated HTML, generated Markdown mirrors, or compiled assets directly.
- Before treating an unfamiliar `.md` or asset as generated, inspect its source relationship. Do not delete tracked generated files merely because they are reproducible.

## Prose and code

- Keep scientific and database claims precise, conservative, and traceable to a source, tagged artifact, schema, or generated result.
- Do not hardcode analysis-derived values when a reproducible computation can provide them.
- Use one complete sentence per source line for new Quarto prose; do not split a sentence to satisfy a fixed-width limit.
- R chunks follow `.ai/r-coding.md`, use `here::i_am()`/`here::here()` where appropriate, and avoid depending on interactive state.
- Do not expose `.secrets`, licensed source data, local absolute paths, or private storage locations in rendered output.

## Rendering and review

- Render only when a source change requires generated artifacts to be updated.
- Use `quarto render` from the repository root so the pre-render theme generation runs.
- After rendering, inspect command output, changed artifacts, links, images, navigation, and representative pages at desktop and narrow widths.
- Treat absolute local paths in generated Markdown or HTML as defects; rendered public artifacts must be portable.
- Keep `README.md` and `docs/` changes with their source changes when the repository tracks them.
