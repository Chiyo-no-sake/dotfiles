# Global Agent Rules

## Worktree Safety (Non-Negotiable)

- These rules apply to every primary agent and subagent.
- Git worktrees MUST be created only inside the owning repository at
  `<repo-root>/worktrees/<branch-or-task-name>`.
- NEVER create, edit, or retain a Git worktree under `/tmp`, `/tmp/opencode`,
  `/var/tmp`, the home directory, or any path outside the owning repository.
- Before creating a worktree, verify `<repo-root>/worktrees/` exists and that it
  is ignored by the repository. If the convention is absent or unclear, stop and
  ask the user; do not choose an alternate location.
- `/tmp` is only for disposable non-Git artifacts. It must never contain work
  that has not already been committed and pushed.
- Before reporting work complete or removing a worktree, commit and push the
  intended changes. Verify local `HEAD` matches its remote branch.

## Code retrieval tool selection (Serena is installed)

When the Serena MCP server is connected, you MUST prefer its symbolic tools over text
search for the following task types. Text search (`grep`, `rg`, `search_for_pattern`)
is structurally incomplete for these because it cannot see destructuring, aliased
imports, callback references, reflection, or spread calls.

| Task | REQUIRED tool | NEVER use |
|------|---------------|-----------|
| "Who calls function/method X?" | `mcp__serena__find_referencing_symbols` | `grep`, `search_for_pattern` |
| "Who implements interface I?" | `mcp__serena__find_implementations` | `grep`, `search_for_pattern` |
| "Where is X defined?" | `mcp__serena__find_declaration` | `grep`, `search_for_pattern` |
| "What's the structure of class/module M?" | `mcp__serena__get_symbols_overview` then `find_symbol` with `include_body=True` for the parts you need | Reading the whole file |
| "If I change the signature of X, what breaks?" | `mcp__serena__find_referencing_symbols` (callers) + `find_implementations` (subtypes) | `grep` |
| "Rename X everywhere" | `mcp__serena__rename_symbol` | `grep` + replace |

### When `search_for_pattern` / `grep` are the right tool

- You don't yet know the symbol name and need to discover candidates (then switch to `find_symbol`)
- Searching inside string literals, comments, configs, or non-source files
- Searching for a regex pattern that has no symbol equivalent

### Workflow when planning a feature or refactor

For every function, method, class, or interface you'll touch in the plan, you MUST run
`find_referencing_symbols` to map its callers before writing the plan. A plan that lists
"files to change" without having enumerated the callers via the LSP is incomplete and
will undercount the blast radius. Do not substitute `grep` for this — grep will miss
references that the type system knows about.

### If Serena is not connected

Fall back to `grep`/`rg` and warn the user that the result may be incomplete.
