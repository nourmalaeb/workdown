---
name: workdown
description: Read and maintain private team documentation (*.wrk.md files) that lives alongside code but is tracked in a separate private "workdown" git repo via the `wrkdwn` CLI. Use this skill whenever you are working in a repository that contains a .workdown.git directory or any *.wrk.md files, whenever the user mentions wrkdwn, workdown, workdown docs, or workdown repo, and whenever you are about to plan, modify, or explain code in such a repository — read the relevant workdown docs BEFORE making changes, and record decisions, caveats, and TODOs in them AFTER making changes.
---

# Workdown docs

This repository has a private documentation layer: files ending in `.wrk.md`
sit next to the code they describe but are tracked in a separate private repo
(`.workdown.git`), managed with the `wrkdwn` CLI. The public repo's git never sees
them. They are authoritative team context: plans, decisions, tradeoffs,
gotchas, and TODOs.

## Before changing code

1. Look for `.wrk.md` files in the directory you're working in and its
   ancestors (e.g. `find . -name '*.wrk.md'` from the repo root, or check the
   nearest ones). Read them — they often explain why the code is the way it is.
2. Check `PLANS/` at the repo root (if present) for cross-cutting docs.

## Where to put docs

Docs live **next to the code they describe**. An agent or teammate editing
`src/auth/middleware.ts` should find context in `src/auth/Doc.wrk.md` or
`src/auth/middleware.wrk.md` — not in a top-level wiki they have to remember
to consult.

Naming:
- `Doc.wrk.md` — the directory-level doc. Describes what the directory as a
  whole does, cross-cutting decisions, and gotchas for anyone working in it.
- `<feature>.wrk.md` — a file-level doc for a specific complex file (e.g.
  `wrkdwn.wrk.md` next to the `wrkdwn` binary). Use when a single file
  carries enough history or decisions to warrant its own doc.

When creating a new doc: start with frontmatter only (`docs:`, `status:`,
`todos:` if any). Add body entries as decisions are made. A stub is better
than no doc — it signals that the directory is documented even before anything
interesting has happened.

## Frontmatter (optional)

`.wrk.md` files may open with YAML frontmatter. All fields are optional — omit
any that aren't relevant. Scan frontmatter before reading the body to decide
how carefully to engage with the full doc.

```yaml
---
docs: "One-liner describing what this feature or directory does"
status: active          # planned | active | stable | deprecated | archived
contributors:
  - github-username
todos:
  - one-liner per outstanding action item
gotchas:
  - one-liner per trap or non-obvious constraint
human_notes:
  - one-liner per thing a human should know before the session starts
related:
  - ../path/to/other/Doc.wrk.md
archived_from: path/to/original/Doc.wrk.md   # only present when status: archived
archived_reason: "why the feature/directory was removed"    # only present when status: archived
---
```

When writing entries: add to `todos:` for new action items, `gotchas:` for
traps you hit, `human_notes:` for things a human should know. Remove resolved
`todos:` entries — the body entry is the permanent record. Keep each line
short; full context belongs in the body.

## After changing code

Record anything a teammate or future agent would need: non-obvious decisions,
rejected alternatives, gotchas you hit, unfinished work. Append to the nearest
relevant `.wrk.md`, or create one next to the code. Keep entries short,
dated, and signed — identify people by their GitHub username, and agents by
agent name:

```markdown
## 2026-06-11 — session token redesign (nourmalaeb + claude)
Decision: rotate refresh tokens on every use. Tradeoff: ...
Gotcha: KV eventual consistency means ...
TODO: backfill expiry on legacy rows before removing fallback.
```

### When to include a PR reference

Include a `PR:` line when the change is significant enough that a reviewer
would want to trace the full discussion: a new feature, a removal, or an
architectural decision. Skip it for routine fixes or small tweaks.

To get the current PR number run `gh pr view --json number,url` (returns
nothing if no open PR exists yet — omit the reference in that case).

```markdown
## 2026-06-11 — session token redesign (nourmalaeb + claude)
PR: https://github.com/org/repo/pull/42
Decision: rotate refresh tokens on every use. Tradeoff: ...
Gotcha: KV eventual consistency means ...
TODO: backfill expiry on legacy rows before removing fallback.
```

## Committing workdown docs

Use `workdown`, which is git scoped to the private repo:

```bash
wrkdwn status
wrkdwn add path/to/file.wrk.md
wrkdwn commit -m "describe the docs change"
wrkdwn push
```

NEVER commit `.wrk.md` files with plain `git`, and never use `git add -f` on
them. If `wrkdwn` is missing or `.workdown.git` doesn't exist, run `wrkdwn init`
(or tell the user) rather than improvising.

## Archiving deleted docs

When code is removed, its `.wrk.md` docs should be archived to
`.WORKDOWN-ARCHIVE/` rather than deleted — history and decisions remain useful
after the code is gone. `.WORKDOWN-ARCHIVE/` is invisible to the public repo
(it only contains `.wrk.md` files).

**Reading `wrkdwn status` output for deletions:**

- Staged `D` (first column: `D `) — deletion was done via `wrkdwn rm`;
  intentional, just needs a commit.
- Unstaged `D` (second column: ` D`) — deletion happened outside wrkdwn;
  surface these to the human and ask what to do before committing anything.

**Before removing a directory**, run `wrkdwn status` to find any `.wrk.md`
files inside it. Show them to the human and ask: archive or permanently delete?

**Archive flow:**
1. Restore: `wrkdwn checkout main -- <original-path>`
2. Add to frontmatter:
   ```yaml
   status: archived
   archived_from: <original-path-relative-to-repo-root>
   archived_reason: "one-liner: why the feature/directory was removed"
   ```
3. Move: `mkdir -p .WORKDOWN-ARCHIVE/<original-dir> && mv <original-path> .WORKDOWN-ARCHIVE/<original-path>`
4. Stage: `wrkdwn rm <original-path> && wrkdwn add .WORKDOWN-ARCHIVE/<original-path>`
5. Commit: `wrkdwn commit -m "archive docs for removed <feature>"`

Use `wrkdwn rm <file.wrk.md>` to permanently delete a doc with no archiving.

## Confidentiality rules (critical)

- NEVER quote, paste, or summarize the contents of any `.wrk.md` file in
  commit messages, PR titles or descriptions, issue comments, code comments,
  or any other artifact that lands in the public repo.
- Referring to a doc by filename is acceptable; reproducing its contents is not.
- Never run `wrkdwn clean` (the wrapper blocks it; do not work around the block —
  from the workdown repo's view the entire codebase is "ignored files").
