#!/usr/bin/env bash
#
# install.sh - Install the Contains Studio AI agent collection into a
#              coding assistant's agents directory.
#
# Usage:
#   ./scripts/install.sh [--tool <tool>] [--dry-run] [<department>...]
#   ./scripts/install.sh --list
#   ./scripts/install.sh --help
#
# Examples:
#   ./scripts/install.sh --tool claude-code            # install all agents
#   ./scripts/install.sh --tool claude-code engineering # install one department
#   ./scripts/install.sh --list                        # show available agents
#
set -euo pipefail

# --- Resolve the repository root (parent of this scripts/ directory) --------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEPARTMENTS=(
  engineering
  design
  marketing
  product
  project-management
  studio-operations
  testing
  bonus
  presto
)

TOOL="claude-code"
DRY_RUN=0
SELECTED=()

usage() {
  cat <<'EOF'
Install the Contains Studio AI agent collection.

Usage:
  ./scripts/install.sh [--tool <tool>] [--dry-run] [<department>...]
  ./scripts/install.sh --list
  ./scripts/install.sh --help

Options:
  --tool <tool>   Target assistant. Supported: claude-code (default).
  --dry-run       Show what would be copied without writing any files.
  --list          List every available agent grouped by department.
  --help          Show this help text.

Departments:
  engineering  design  marketing  product
  project-management  studio-operations  testing  bonus  presto

If no department is given, every department is installed.
EOF
}

# --- Map a tool name to its agents directory -------------------------------
target_dir_for_tool() {
  case "$1" in
    claude-code) printf '%s/.claude/agents' "$HOME" ;;
    *)
      echo "error: unsupported --tool '$1' (supported: claude-code)" >&2
      exit 1
      ;;
  esac
}

list_agents() {
  for dept in "${DEPARTMENTS[@]}"; do
    dir="$REPO_ROOT/$dept"
    [ -d "$dir" ] || continue
    echo "$dept:"
    for agent in "$dir"/*.md; do
      [ -e "$agent" ] || continue
      echo "  - $(basename "$agent" .md)"
    done
  done
}

# --- Parse arguments -------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --tool)
      [ $# -ge 2 ] || { echo "error: --tool requires a value" >&2; exit 1; }
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --list)
      list_agents
      exit 0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      echo "error: unknown option '$1'" >&2
      usage >&2
      exit 1
      ;;
    *)
      SELECTED+=("$1")
      shift
      ;;
  esac
done

# --- Determine which departments to install -------------------------------
if [ "${#SELECTED[@]}" -eq 0 ]; then
  SELECTED=("${DEPARTMENTS[@]}")
else
  for dept in "${SELECTED[@]}"; do
    found=0
    for known in "${DEPARTMENTS[@]}"; do
      [ "$dept" = "$known" ] && found=1
    done
    if [ "$found" -eq 0 ]; then
      echo "error: unknown department '$dept'" >&2
      echo "known departments: ${DEPARTMENTS[*]}" >&2
      exit 1
    fi
  done
fi

TARGET_DIR="$(target_dir_for_tool "$TOOL")"

echo "Tool:        $TOOL"
echo "Target:      $TARGET_DIR"
echo "Departments: ${SELECTED[*]}"
[ "$DRY_RUN" -eq 1 ] && echo "Mode:        dry-run (no files written)"
echo

if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$TARGET_DIR"
fi

count=0
for dept in "${SELECTED[@]}"; do
  dir="$REPO_ROOT/$dept"
  if [ ! -d "$dir" ]; then
    echo "warning: department directory not found: $dir" >&2
    continue
  fi
  for agent in "$dir"/*.md; do
    [ -e "$agent" ] || continue
    name="$(basename "$agent")"
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "would install: $dept/$name"
    else
      cp "$agent" "$TARGET_DIR/$name"
      echo "installed: $dept/$name"
    fi
    count=$((count + 1))
  done
done

echo
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run complete: $count agent(s) would be installed."
else
  echo "Done: $count agent(s) installed to $TARGET_DIR"
  echo "Restart your assistant to activate the new agents."
fi
