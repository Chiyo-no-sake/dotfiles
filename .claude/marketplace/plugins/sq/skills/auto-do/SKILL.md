---
name: auto-do
description: Autonomously take a Sartiq YouTrack issue from ticket to open pull request across the shootify repos (backend, compute-server, webapp). Fetches the issue, locates the affected code, scopes which repos change, creates a worktree per repo off dev, deeply analyzes the design, writes and reviews a minimal implementation plan, implements it, regenerates API clients, writes and runs tests, syncs with dev, and opens PRs to dev. Use when the user wants to fully execute / "auto-do" a Sartiq task end-to-end (e.g. "auto-do SHO-1234", "auto-do SAR-1234", "run auto-do on this ticket").
---

# Auto-Do

Drive a Sartiq YouTrack issue from ticket to open pull request, fully autonomously, across the three `shootify` repositories.

This skill is an **orchestrator**. Where an existing `sq-dev` skill already owns a step, **invoke it** (via the Skill tool) instead of re-implementing it — that skill is the authoritative source for its conventions. Use the YouTrack and `sartiq-docs` MCP servers for context.

## Operating principles

- **DRY / KISS / SRP.** Reuse existing code, patterns, and skills. Prefer a layered change (model → business logic → API → generated client → UI) over scattered edits. Don't reinvent what a skill already owns.
- **Smallest correct change.** Keep the plan scoped and neat. When scope starts to escalate, stop and re-evaluate whether the new "threat" is real before expanding — hold the line if it isn't.
- **No new bugs.** Respect each repo's data model, transaction boundaries, state management, and architecture. When unsure, read the code and the docs — never guess.
- **Autonomous & non-interactive.** Run start to finish without asking the user to confirm intermediate steps. Every sub-step that is normally interactive (conflict resolution, PR creation) MUST run **non-interactively**. Only stop for the guardrails below.

## Inputs

- **Issue ID** (required): the YouTrack identifier (e.g. `SHO-1234` or `SAR-1234`). Take it from the invocation args or infer it from the conversation. If none can be determined, ask the user — this is the one required input.

## Context: repos & tooling

The three repositories live under `~/repos/shootify/`:

| Role | Path | Stack | Tests | Default branch |
|------|------|-------|-------|----------------|
| Backend API | `~/repos/shootify/shootify-backend` | Python · `uv` · Alembic (`alembic.ini`, `app/alembic/versions`) | `uv run` test suite | `dev` |
| Compute server | `~/repos/shootify/shootify-compute-server` | Python · `uv` | `uv run` test suite | `dev` |
| Webapp | `~/repos/shootify/shootify-webapp` | TypeScript · `pnpm` | `pnpm test` (jest), `pnpm test:e2e` (Playwright + MSW), `pnpm lint`, `pnpm type-check` | `dev` |

**Always read each involved repo's own `CLAUDE.md` AND `AGENTS.md`** for authoritative conventions, layering rules, quality gates, and exact commands — they override anything assumed here (the backend's `CLAUDE.md` explicitly says read `AGENTS.md` first). Use the `sartiq-docs` MCP server for domain/architecture/standards, and `context7` for third-party library docs.

API client direction: **compute-server → backend → webapp** (each service generates a typed client for the service it calls upstream).

## Guardrails — stop and ask the user only if

- No issue ID can be determined.
- After reading the issue and the related code, the requirement is too ambiguous to scope a safe change.
- A worktree/branch already exists for this issue (surface it; don't silently clobber).
- A destructive or irreversible operation **outside the worktrees** would be required.
- After reasonable iteration, tests cannot be made to pass, or migrations / client generation structurally cannot complete.

Otherwise, proceed without prompting.

---

## Phase 1 — Fetch the issue

1. **Normalize the issue ID.** Sartiq remaps `SHO-…` → `SAR-…`. Normalize with the `sq-dev` helper:
   `bash "$(find -L ~/.claude/plugins/cache/sartiq-marketplace/sq-dev -name extract-issue-id.sh -type f 2>/dev/null | head -1)" "<raw-id>"` — fall back to the raw input if it returns empty.
2. Fetch with the YouTrack MCP tools: `get_issue` (summary, description, type, priority, custom fields, linked issues) and `get_issue_comments` (discussion, acceptance details). Stop if the issue isn't found.

Extract what the change must accomplish, acceptance criteria, affected features, and explicit constraints. Hold this as the source of truth for "done".

## Phase 2 — Locate the code & scope the repositories

Before touching anything, understand where this feature lives. Use parallel `Explore` subagents (one per repo / feature area) to keep the main context lean — ask them to **locate and summarize**, not dump files:

- Find the models, services / business logic, API routes, tasks / processors, and UI surfaces related to the issue.
- Identify the main entities, their relationships, and the existing data/control flow.

Then decide **which of the three repos must change** — only include a repo that genuinely needs edits:

- Pure UI/UX → `shootify-webapp` only.
- New/changed API behavior → `shootify-backend` (+ `shootify-webapp` for the regenerated client/UI).
- Heavy/async processing or model inference → `shootify-compute-server` (+ `shootify-backend` to call it, + webapp downstream).

State the involved repos and a one-line reason for each before proceeding.

## Phase 3 — Worktrees (one per involved repo)

`sq-dev:start-task` defines the **branch naming and base** but it branches in place (no worktree) and is user-invocation-only, so replicate its conventions here per involved repo. Auto-do needs an isolated **worktree** per repo because it works on several repos at once.

For each involved repo:

1. `git -C <repo> fetch origin dev`.
2. Slugify the issue summary: lowercase, spaces→hyphens, strip everything except `a-z0-9-`, collapse and trim hyphens.
3. Branch name (start-task convention): **`<ISSUE-ID>/<slug>`** (e.g. `SAR-1234/add-retry-logic`) — note: `<ISSUE-ID>` first, no `feat/`/`fix/` prefix.
4. Create the worktree off `dev`:
   `git -C <repo> worktree add -b <ISSUE-ID>/<slug> ../<repo-name>-worktrees/<ISSUE-ID> origin/dev`
   (start-task does not define a worktree location; use this sibling path, e.g. `~/repos/shootify/shootify-backend-worktrees/SAR-1234`).
5. Recreate the environment in the worktree per its `CLAUDE.md`: copy `.env` / `.env.local`, then `uv sync` (Python repos) or `pnpm install` (webapp) — do **not** copy `.venv` / `node_modules` for normal work.
6. Remote tracking is set on first push (`git push -u origin <ISSUE-ID>/<slug>`), done in Phase 11.

Once, for the issue (not per repo): assign it to the current user and set state **In Progress** via the YouTrack MCP tools (`get_current_user`, `change_issue_assignee`, `update_issue` → `State: In Progress`); warn but continue if these fail.

All subsequent work for a repo happens **inside its worktree**, never in the main checkout. If a worktree for this issue already exists, follow the guardrail.

## Phase 4 — Deep analysis

Per involved repo, build an accurate mental model of:

- **Data model**: entities, fields, relationships, constraints, nullability, enums.
- **Data flows**: how data enters, moves through layers, and is persisted/returned.
- **State management**: frontend stores/queries; backend caches/sessions; idempotency.
- **Business logic**: invariants, validation, edge cases, permissions.
- **Transactions**: where transactions begin/commit, what must be atomic, failure/rollback behavior.
- **Architecture & structure**: layering, module boundaries, where new code belongs (per `AGENTS.md`).
- **Conventions**: naming, error handling, testing, migrations, API/client patterns.

Cross-reference `sartiq-docs` for documented standards and recipes.

## Phase 5 — Implementation plan

Produce a single, scoped plan that solves the issue with neat, layered changes and **no new bugs**. The plan must:

- Reuse existing code and patterns; follow each repo's conventions and quality gates.
- Be ordered by layer and cross-repo dependency (e.g. backend model + Alembic migration → backend service → backend API → webapp client regen → webapp UI; compute changes precede the backend code that calls them).
- List concrete files to add/change and the test strategy for each.
- Explicitly flag any API contract change (compute→backend, backend→webapp) so client regeneration is planned, not discovered late.
- Stay minimal — no speculative abstractions, no over-engineering.

## Phase 6 — Review the plan (iterate)

Review the plan adversarially **before writing code**:

- Walk each change against the data model, transactions, and edge cases. Does it break existing flows? Are migrations safe and reversible? Are contract changes accounted for downstream?
- Fix issues found, then re-review. Keep the plan **small** — if a finding pushes scope up, confirm the risk is real before expanding.
- Iterate until no real correctness concern remains, then proceed.

## Phase 7 — Implement

Implement the plan from start to finish, exactly as written, layer by layer within each worktree. Match surrounding style and each repo's conventions. Keep commits atomic and conventional (see `sq-dev:commit-conventions`; use `sq-dev:make-commit`). If reality forces a deviation, make the smallest sound adjustment and note it — don't silently drift.

## Phase 8 — Regenerate API clients

After any contract change, keep generated clients in sync (direction: compute-server → backend → webapp). There is **no** dedicated generate-client skill — use each repo's own generator:

- **Backend API changed → regenerate the webapp TypeScript client:** `pnpm generate-client` in the webapp (it runs `generate-client.sh`; built on `openapi-typescript-codegen`). Confirm in `webapp/package.json` / `CLAUDE.md`.
- **Compute-server API changed → regenerate the backend's client for compute:** discover the backend's mechanism from its `CLAUDE.md` / `AGENTS.md` / `scripts` and run it.

Generation needs the **upstream** service's OpenAPI schema, which usually means a **running upstream instance**. To provide one, stand up a **local, isolated, throwaway** instance:

- Copy the source repo's **`.env` and `.venv`** into the worktree (intentional for the throwaway instance — distinct from Phase 3, which does not copy `.venv`).
- **Change ports** (DB, API, compute, etc.) so they don't collide with any other running environment.
- Start the upstream service, run generation against it, then tear the instance down.

Commit each regenerated client in its own commit. Never hand-edit generated files.

## Phase 9 — Tests

Write and run tests appropriate to each layer:

- **Unit tests** for new/changed business logic.
- **Integration tests** for API endpoints, persistence, transactions, and cross-service calls.
- **MSW-mocked e2e tests** for the webapp where applicable (`pnpm test:e2e` — Playwright with MSW).

Run each repo's suites with its documented commands (backend/compute via `uv run`; webapp via `pnpm test` and `pnpm test:e2e`). Iterate on code and tests until **everything passes**.

## Phase 10 — Sync with dev & re-verify

Before opening PRs, get current with the latest `dev` in each involved worktree:

1. `git fetch origin dev` and merge `origin/dev` into the task branch.
2. If there are conflicts, resolve them by invoking **`sq-dev:solve-conflicts`** run **NON-INTERACTIVELY** — do not prompt the user. (IMPORTANT.)
3. **Backend**: check for multiple Alembic migration heads introduced by the merge — `uv run alembic heads`. If there is more than one head, create a merge migration (`uv run alembic merge`) / re-order so there is a single head, and verify migrations apply cleanly.
4. Regenerate the webapp (and/or backend) client again if the merge changed an upstream contract (Phase 8).
5. Re-run all test suites plus linters/type checks (`sq-dev:code-check`). Fix anything the merge broke.
6. Run a final review pass with **`sq-dev:full-review`** (code-check + code-review + simplify) and address real findings.

## Phase 11 — Push & open PRs

For each involved worktree, invoke **`sq-dev:create-pr`** (non-interactively). It pushes the branch with tracking, generates the title/body from commits, links the YouTrack issue, and **targets `dev`** by default. If multiple repos changed, open one PR per repo and cross-reference them in the PR bodies so they're reviewed together.

## Completion

Report back: the issue, the repos touched, the worktrees/branches, the PR links, test/lint/migration status, and any deviations from the plan or items left for the reviewer. The work is done once every involved repo has a green, pushed branch with an open PR to `dev`.
