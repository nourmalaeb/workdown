# workdown docs (paste into CLAUDE.md / AGENTS.md)

## workdown documentation (`*.wrk.md`)

Files ending in `.wrk.md` are private team documentation that lives alongside
the code but is tracked in a separate private repo. They are authoritative
context: plans, decisions, caveats, gotchas, and TODOs for the code next to them.

Rules:

- ALWAYS read any `.wrk.md` file in or above a directory you are working in
  before making changes there.
- When you make a non-obvious decision, hit a gotcha, or leave work unfinished,
  record it in the nearest relevant `.wrk.md` (create one next to the code if
  none exists). Keep entries short and dated.
- Commit workdown docs with `workdown add <file> && workdown commit -m "..."` — NEVER
  with plain `git`. Plain `git` must never see these files.
- NEVER quote, paste, or summarize the contents of a `.wrk.md` file in commit
  messages, PR titles/descriptions, code comments, or issue comments on the
  public repo. Referring to a doc by filename is fine; its contents are not.
- `repo-root/PLANS/` holds cross-cutting docs (architecture, roadmap);
  per-directory docs hold local context. Prefer local.

Conventions for doc content:

```markdown
# sessions.wrk.md
## 2026-06-11 — session token redesign (nour + claude)
Decision: rotate refresh tokens on every use. Tradeoff: ...
Gotcha: KV eventual consistency means ...
TODO: backfill expiry on legacy rows before removing fallback.
```
