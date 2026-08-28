# VegVault Review Checklist

Report findings first, ordered by severity and grounded in file paths. If no findings exist, say so and identify any validation that could not be run.

## Review flow

1. Group changed files by Git root and preserve unrelated work.
2. Map each file to `AGENTS.md` and the relevant `.ai/` guidance.
3. Review behavior, data contracts, safety, documentation, and validation rather than style alone.
4. Check downstream repositories whenever a producer artifact or SQLite contract changes.

## Required checks

- New or materially edited R code follows `.ai/r-coding.md` without unrelated legacy churn.
- Paths are portable, private data remain private, and overwrite controls remain safe by default.
- Expensive operations were not run without explicit authorization.
- Producer filenames, columns, units, partitions, and provenance remain compatible or have a coordinated migration.
- SQL, DBML, version metadata, website documentation, and `vaultkeepr` fixtures remain synchronized for schema changes.
- Quarto/README edits target sources and tracked generated outputs were reviewed after rendering.
- Tool adapters point to canonical `.ai/` files and do not contain diverging long-form policy.
- Validation is proportional and results are reported separately for each repository.

Run `git diff --check` in every affected repository. Do not stage, commit, push, or clean the worktree as part of review.
