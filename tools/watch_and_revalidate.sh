#!/usr/bin/env bash
# Pull main / sibling branches and re-run QA. Designed for Agent E poll loop.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.local/bin:${PATH}"

echo "[watch] fetching origin @ $(date -u +%H:%M:%SZ)"
git fetch origin --prune 2>&1 || true

# Show what landed
echo "[watch] remote branches:"
git branch -r | head -40

# Merge main into current QA branch if it advanced (prefer rebase for cleanliness)
if git rev-parse --verify origin/main >/dev/null 2>&1; then
  LOCAL_MAIN="$(git rev-parse main 2>/dev/null || true)"
  REMOTE_MAIN="$(git rev-parse origin/main)"
  if [[ "${LOCAL_MAIN}" != "${REMOTE_MAIN}" ]]; then
    echo "[watch] origin/main moved -> ${REMOTE_MAIN}"
    git merge --no-edit origin/main || {
      echo "[watch] merge conflict — leaving unresolved for Agent E"
      git merge --abort 2>/dev/null || true
    }
  else
    echo "[watch] origin/main unchanged"
  fi
fi

# Also try merging open feature branches that look like content/core/systems/ui
for b in $(git branch -r | sed 's|^[[:space:]]*||' | grep -E 'origin/cursor/' | grep -v HEAD || true); do
  short="${b#origin/}"
  case "${short}" in
    *qa*|*validation*) continue ;;
  esac
  echo "[watch] attempting merge ${short}"
  if git merge --no-edit "${b}"; then
    echo "[watch] merged ${short}"
  else
    echo "[watch] skip ${short} (conflict)"
    git merge --abort 2>/dev/null || true
  fi
done

echo "[watch] content tree:"
find content -type f 2>/dev/null | head -50 || echo "(no content yet)"
ls -la project.godot HANDOFF.md 2>/dev/null || true

bash tools/run_qa_suite.sh || true
