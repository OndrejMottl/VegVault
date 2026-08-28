# VegVault Agent Guide

This file is the universal entry point for assistants working on the VegVault data-production suite. Canonical guidance lives in `.ai/`; tool-specific files are compatibility adapters only.

## Required reading

| Task | Read first |
| --- | --- |
| Any work in this repository or a sibling producer repository | `AGENTS.md`, `.ai/suite-architecture.md` |
| R scripts, functions, data processing, or visualisation | `.ai/r-coding.md` |
| SQLite schema, imports, database assembly, or database validation | `.ai/database.md` |
| Quarto, website, README, styles, or rendered documentation | `.ai/quarto.md` |
| Git, branches, worktrees, commits, or pull requests | `.ai/git-workflow.md` |
| Suggesting, writing, or reviewing a commit message | `.ai/git-workflow.md`, then `.ai/commit-messages.md` |
| Debugging or bug fixes | `.ai/debugging.md` |
| Reviewing changed files | `.ai/review-checklist.md` |
| Reusable review or planning workflows | `.ai/agents/changes-reviewer.agent.md`, `.ai/agents/plan-large-changes.agent.md` |

## Repository family

The producer repositories are normally sibling checkouts under any suite root:

```text
<vegvault-suite-root>/
├── VegVault/                     # Integration, SQLite assembly, website
├── VegVault-FOSSILPOL/           # Fossil-pollen producer
├── VegVault-Vegetation_data/     # BIEN and sPlot producer
├── VegVault-abiotic_data/        # CHELSA and WoSIS producer
└── VegVault-Trait_data/          # TRY and BIEN-trait producer
```

Producer repositories read this guide through their local `AGENTS.md` when the sibling checkout is available. Their local fallback contracts remain binding if it is not. `vaultkeepr` is an independent R package and database consumer that may be checked out anywhere; discover its location from the active workspace or ask the user rather than assuming a machine-specific path.

## Tool adapters

- GitHub Copilot uses `.github/copilot-instructions.md`, `.github/instructions/`, and `.github/agents/`.
- GitHub Copilot commit-message generation uses `.github/commit-instructions.md`, which routes to the canonical `.ai/commit-messages.md`.
- Claude and Gemini use root redirect files that point here.
- Cursor uses `.cursor/rules/*.mdc` for project and file-glob routing.
- Other assistants should load `AGENTS.md` and then the relevant `.ai/` files.

The `.ai/` files are canonical. Keep adapters short and do not duplicate long-form policy in them.
