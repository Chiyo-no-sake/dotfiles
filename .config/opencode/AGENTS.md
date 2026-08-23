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
- When a repository provides `scripts/worktree/create-worktree.sh`, use it
  instead of raw `git worktree add`. The bootstrap copies the gitignored files
  declared in `.worktreeinclude` (such as `.env` and `.env.local`) that local
  tooling needs. Do not manually recreate that bootstrap unless the script is
  unavailable.
- `/tmp` is only for disposable non-Git artifacts. It must never contain work
  that has not already been committed and pushed.
- Before reporting work complete or removing a worktree, commit and push the
  intended changes. Verify local `HEAD` matches its remote branch.
