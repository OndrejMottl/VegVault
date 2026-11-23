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

## Issue, pull-request, and comment text

Write every issue, pull request, and comment for a reader who knows ecology and R but has never seen this work: a collaborator, a reviewer, or the maintainer months later. Assume they have not read the release plan, other issues, design notes, chat sessions, or the agent's working files. The text must explain itself; links are supporting evidence, never a replacement for the explanation.

Include:

- An opening of two or three plain sentences: what this is about, why it matters, and what the reader is asked to do (review, decide, or nothing).
- The background the reader needs: which repository and data source, what happens now, and what is wrong or missing. Explain each project-specific term on first use, in one clause, even when you also link to its definition.
- For an issue: the task and what "done" means, as checkable points.
- For a pull request: what changed and why, what was checked (the actual command or test and its result, with numbers), what was not checked, and any decision left for the reader.
- For every reference to another issue, pull request, decision, or note: a few words on what it is or what it decided. "As agreed in #<n>" is not enough; "#<n> decided to keep the TRY trait records and drop duplicates" is.

Do not use:

- Plan codes, phase or stage numbers, work-package or checkpoint labels, or decision numbers (for example `G2`, `L5`, `a03`, `decision 10`) unless the same text says in plain words what they are.
- Private shorthand from a working session ("the rehearsal database", "the parity check", "the subset") without saying what it is.
- "As discussed", "per the plan", or "see above" in place of the content itself.

Keep it concise. Lead with the summary, use short headed sections (`Background`, `Changes`, `Checks`, `Open questions`) only where they help, and put long evidence in a collapsed `<details>` block or a linked file.

Before posting, reread the text as that newcomer would. If they could not tell what problem it addresses, what changed or is needed, and how it was or will be verified without opening any link, add the missing explanation.
