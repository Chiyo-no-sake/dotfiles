#!/usr/bin/env bash
# Companion to ~/.config/systemd/user/dev-cage-watcher.service.
#
# Every second, any process matching a rule below — plus its ENTIRE subtree —
# is migrated into the rule's cage unit, where CPUQuota/MemoryMax apply no
# matter how it was launched (agent shells, bunx, uv run, bun run scripts).
#
# Subtree migration matters: writing a parent pid to cgroup.procs does NOT
# move its already-spawned children, and dev tooling runs as multi-process
# chains (bun run quality → node …/bin/tsc, uv run pytest → python -m pytest
# → xdist workers). Matching the root and walking descendants cages them all.
#
# Patterns only match real invocations (script paths, "run <script>" argv),
# so commands that merely mention a tool (grep, pkill, editors) are never
# caged. Over-limit memory is OOM-killed inside the cage only.
set -u

# rule syntax: pgrep -f regex|cage-unit
RULES=(
  'node_modules/[^ ]*bin/tsc( |$)|tsc-cage.service'
  'bun run quality|tsc-cage.service'
  'npm run quality|tsc-cage.service'
  'uv run pytest|pytest-cage.service'
  'bin/pytest( |$)|pytest-cage.service'
  'python[^ ]* -m pytest( |$)|pytest-cage.service'
)

declare -A CG_PATHS

descendants() { # pid → pids of children, recursively
  local p=$1 c
  for c in $(pgrep -P "$p" 2>/dev/null); do
    printf '%s\n' "$c"
    descendants "$c"
  done
}

while true; do
  for rule in "${RULES[@]}"; do
    pattern=${rule%%|*}
    unit=${rule##*|}
    path=${CG_PATHS[$unit]:-}
    if [ -z "$path" ] || [ ! -w "/sys/fs/cgroup${path}/cgroup.procs" ]; then
      path=$(systemctl --user show -p ControlGroup --value "$unit" 2>/dev/null)
      CG_PATHS[$unit]=$path
    fi
    [ -n "$path" ] && [ -w "/sys/fs/cgroup${path}/cgroup.procs" ] || continue

    for pid in $(pgrep -f "$pattern" 2>/dev/null); do
      for m in $pid $(descendants "$pid"); do
        echo "$m" > "/sys/fs/cgroup${path}/cgroup.procs" 2>/dev/null || true
      done
    done
  done
  sleep 1
done
