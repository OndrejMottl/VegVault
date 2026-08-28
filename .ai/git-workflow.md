# VegVault Git Workflow Guidance

This guidance applies independently in every Git repository in the VegVault suite.

## Commit message requests

Before suggesting, generating, or reviewing any commit message, read `.ai/commit-messages.md` in the current turn. Treat it as the canonical source for format, subject selection, banned wording, length, and response shape. Inspect the actual diff or staged scope first; do not infer a message from a task description alone.

## User control

Never perform a state-changing Git or GitHub operation without a direct user request for that operation. This includes staging, committing, pushing, merging, rebasing, deleting branches, removing worktrees, creating releases/tags, or opening pull requests. Read-only status, diff, log, branch-list, and worktree-list operations are allowed.

An implementation request authorizes requested file edits, not an automatic commit or push. Leave changes uncommitted and unpushed unless separately requested.

Use `git mv` for authorized moves of tracked paths and verify the rename with `git status --short`, `git diff --cached --summary`, and `git diff --cached --check`. Do not commit merely because `git mv` staged the move.

## Multi-repository work

- Establish the Git root, branch, status, and remotes for every repository in scope before editing.
- Never combine files from different repositories into one commit or assume one branch name controls the entire suite.
- Preserve unrelated tracked and untracked work. Report it but do not stage, restore, move, or delete it.
- Validate and report changes grouped by their nearest Git root.

## Branches, worktrees, and releases

- Use `main` as the stable base unless the repository's active release workflow names another integration branch.
- Use a worktree for isolated large changes or when a long-running process occupies the main checkout.
- Do not copy complete raw-data or cache trees between worktrees. Reconnect only the explicitly required external data and copy only intentionally regenerated outputs.
- Producer tags and VegVault database versions are reproducibility contracts. Creating or moving a tag, changing a pinned artifact, or publishing a database release requires explicit authorization and coordinated release notes.

## Durable change descriptions

Commit and pull-request titles should describe durable domain behavior, not temporary plan phases. Keep issue relationships in PR metadata rather than embedding issue numbers in reusable code identifiers.
