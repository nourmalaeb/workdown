---
name: workdown
description: Read and maintain private team documentation (*.wrk.md files) that lives alongside code but is tracked in a separate private "workdown" git repo via the workdown CLI. Use this skill whenever you are working in a repository that contains a .workdown.git directory or any *.wrk.md files, whenever the user mentions workdown, workdown docs, or workdown repo, and whenever you are about to plan, modify, or explain code in such a repository — read the relevant workdown docs BEFORE making changes, and record decisions, caveats, and TODOs in them AFTER making changes.
---

# Workdown docs

This repository has a private documentation layer: files ending in `.wrk.md`
sit next to the code they describe but are tracked in a separate private repo
(`.workdown.git`), managed with the `workdown` CLI. The public repo's git never sees
them. They are authoritative team context: plans, decisions, tradeoffs,
gotchas, and TODOs.

## Before changing code

1. Look for `.wrk.md` files in the directory you're working in and its
   ancestors (e.g. `find . -name '*.wrk.md'` from the repo root, or check the
   nearest ones). Read them — they often explain why the code is the way it is.
2. Check `PLANS/` at the repo root (if present) for cross-cutting docs.

## After changing code

Record anything a teammate or future agent would need: non-obvious decisions,
rejected alternatives, gotchas you hit, unfinished work. Append to the nearest
relevant `.wrk.md`, or create one next to the code. Keep entries short,
dated, and signed:

```markdown
## 2026-06-11 — session token redesign (nour + claude)
Decision: rotate refresh tokens on every use. Tradeoff: ...
Gotcha: KV eventual consistency means ...
TODO: backfill expiry on legacy rows before removing fallback.
```

## Committing workdown docs

Use `workdown`, which is git scoped to the private repo:

```bash
workdown status
workdown add path/to/file.wrk.md
workdown commit -m "describe the docs change"
workdown push
```

NEVER commit `.wrk.md` files with plain `git`, and never use `git add -f` on
them. If `workdown` is missing or `.workdown.git` doesn't exist, run `workdown setup`
(or tell the user) rather than improvising.

## Confidentiality rules (critical)

- NEVER quote, paste, or summarize the contents of any `.wrk.md` file in
  commit messages, PR titles or descriptions, issue comments, code comments,
  or any other artifact that lands in the public repo.
- Referring to a doc by filename is acceptable; reproducing its contents is not.
- Never run `workdown clean` (the wrapper blocks it; do not work around the block —
  from the workdown repo's view the entire codebase is "ignored files").
