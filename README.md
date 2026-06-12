# workdown

**Markdown for work.** A private documentation layer for public repos — plans,
decisions, gotchas, and agent context that live *next to the code* without
ever appearing in your open-source repo.

```
src/auth/
├── sessions.ts
└── sessions.wrk.md   ← private. plain git can't see it. your agents can.
```

You maintain workdown files in a **working copy** of your repo: two git repos
sharing one working tree. The public repo tracks the code and ignores
`*.wrk.md`. A private workdown repo shares the same directory and tracks
*only* `*.wrk.md`. The `workdown` command is just git, scoped to the private
side.

## Why

If your team codes with agents, you rebuild the same context in every session:
the plan lives in Asana, the decision in a Google Doc, the gotcha in someone's
head, the caveat in an agent session from last Tuesday. Checking docs into the
repo would fix it — but the repo is public, and your work-in-progress notes
shouldn't be.

workdown puts that context where humans and agents are already looking — the
file tree — and keeps it access-controlled by an ordinary private GitHub repo.
The source is open; the work doesn't have to be.

## Install

```bash
git clone https://github.com/YOURORG/workdown.git
ln -s "$PWD/workdown/bin/workdown" /usr/local/bin/workdown
```

Requires bash and git. macOS / Linux. (npm package coming.) Want it shorter?
`alias wk=workdown` — the name `wrk` is intentionally avoided, it belongs to
the HTTP benchmarking tool.

## Quickstart

```bash
# 1. Create a private repo next to your public one, named <repo>-workdown
#    e.g. github.com/org/project  →  github.com/org/project-workdown (private!)

# 2. Clone with the workdown layer attached (or `workdown setup` in an existing clone)
workdown clone git@github.com:org/project.git

# 3. Work normally. Write notes next to code as *.wrk.md files.
cd project/src/auth
vim sessions.wrk.md

# 4. Commit notes with workdown; commit code with git. They never mix.
workdown add sessions.wrk.md
workdown commit -m "session redesign plan"
workdown push
```

`workdown clone` derives the private URL by the `-workdown` naming convention;
pass `--private <url>` to override. Everything that isn't a workdown
subcommand passes straight through to git: `workdown log`, `workdown diff`,
`workdown blame`, etc.

## Agents

Install the bundled skill so coding agents (Claude Code, etc.) read workdown
files before touching code and write decisions back afterward:

```bash
workdown skill install     # → ~/.claude/skills/workdown/
```

The skill also enforces the confidentiality rule: agents may reference
workdown files by filename in public artifacts (commits, PRs), but never
quote their contents.

## Leak protection (defense in depth)

The security model is **private-repo access control**, not obscurity — this
tool being public doesn't weaken it. Three layers keep `*.wrk.md` files out of
your public history:

1. **Per-clone excludes** — `workdown setup` writes `*.wrk.md` into
   `.git/info/exclude` (never committed, reveals nothing in the public repo).
2. **pre-push hook** — blocks any push whose commits touch a `.wrk.md`, even
   via `git add -f`.
3. **CI guard** — copy `extras/workdown-guard.yml` into your public repo's
   `.github/workflows/` and make it a required check. It fails if a workdown
   file appears in the tree *or anywhere in pushed history*.

## How it works

`workdown` runs `git --git-dir=.workdown.git --work-tree=<repo root>`. The
private repo is a bare clone living inside your checkout, with a whitelist
exclude (`*` → `!*/` → `!*.wrk.md`) so it sees only workdown files. The public
repo's exclude hides them in the other direction. Two object databases, one
directory, no history rewriting, no sync jobs.

## Footguns handled for you

- `workdown clean` is **disabled** — from the private repo's perspective your
  entire codebase is "ignored files", so `clean -x` would delete it.
- `workdown add .` is safe: the whitelist means it can only ever stage `.wrk.md`.
- `workdown setup` is idempotent; re-run it any time.

## Known limitations

- Fresh `git worktree add` checkouts won't contain workdown files; materialize
  them with `git --git-dir=.workdown.git --work-tree=<worktree> checkout main -- .`
- The private repo stays on a single `main` branch by design — docs persist
  across code-branch switches. Mark branch-specific docs in frontmatter.
- The pre-push hook scans the last 500 commits per push; CI covers the rest.
- Each clone needs `workdown setup` once (or use `workdown clone`).

## License

MIT
