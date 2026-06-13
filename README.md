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
*only* `*.wrk.md`. The `wrkdwn` command is just git, scoped to the private
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
ln -s "$PWD/workdown/bin/wrkdwn" /usr/local/bin/wrkdwn
```

Requires bash and git. macOS / Linux. (npm package coming.)

**Naming:** the project is *workdown*; the command is `wrkdwn` — same
vowel-free scheme as the `.wrk.md` extension, and it avoids colliding with
other `workdown` binaries or `wrk`, the HTTP benchmarking tool.

## Quickstart

```bash
# 1. Create a private repo next to your public one, named <repo>-workdown
#    e.g. github.com/org/project  →  github.com/org/project-workdown (private!)

# 2. Clone with the workdown layer attached (or `wrkdwn init` in an existing clone)
wrkdwn clone git@github.com:org/project.git

# 3. Work normally. Write notes next to code as *.wrk.md files.
cd project/src/auth
vim sessions.wrk.md

# 4. Commit notes with workdown; commit code with git. They never mix.
wrkdwn add sessions.wrk.md
wrkdwn commit -m "session redesign plan"
wrkdwn push
```

`wrkdwn clone` derives the private URL by the `-workdown` naming convention;
pass `--private <url>` to override. Everything that isn't a workdown
subcommand passes straight through to git: `wrkdwn log`, `wrkdwn diff`,
`wrkdwn blame`, etc.

## Agents

Install the bundled skill so coding agents (Claude Code, etc.) read workdown
files before touching code and write decisions back afterward:

```bash
wrkdwn skill install     # → ~/.claude/skills/workdown/
```

The skill also enforces the confidentiality rule: agents may reference
workdown files by filename in public artifacts (commits, PRs), but never
quote their contents.

## Leak protection (defense in depth)

The security model is **private-repo access control**, not obscurity — this
tool being public doesn't weaken it. Three layers keep `*.wrk.md` files out of
your public history:

1. **Per-clone excludes** — `wrkdwn init` writes `*.wrk.md` into
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

- `wrkdwn clean` is **disabled** — from the private repo's perspective your
  entire codebase is "ignored files", so `clean -x` would delete it.
- `wrkdwn add .` is safe: the whitelist means it can only ever stage `.wrk.md`.
- `wrkdwn init` is idempotent; re-run it any time.

## Known limitations

- Fresh `git worktree add` checkouts won't contain workdown files; run
  `wrkdwn materialize` from inside the new worktree to populate them.
- `wrkdwn` commands work from any worktree automatically (discovery via
  `git rev-parse --git-common-dir`). Run `wrkdwn init` from the main checkout only.
- The private repo stays on a single `main` branch by design — docs persist
  across code-branch switches. Mark branch-specific docs in frontmatter.
- The pre-push hook scans the last 500 commits per push; CI covers the rest.
- Each clone needs `wrkdwn init` once (or use `wrkdwn clone`).

## License

MIT
