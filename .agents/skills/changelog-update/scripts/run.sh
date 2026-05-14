#!/bin/bash
# Changelog Update Skill
# Automatically updates CHANGELOG.md based on commits since last release

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
CHANGELOG_PATH="${REPO_ROOT}/${CHANGELOG_FILE}"
DATE_FORMAT="%Y-%m-%d"
TODAY=$(date +"${DATE_FORMAT}")

# ── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo "[changelog-update] $*"; }
err()  { echo "[changelog-update] ERROR: $*" >&2; }
die()  { err "$*"; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || die "Required command not found: $1"
}

# ── Validate environment ──────────────────────────────────────────────────────
require_cmd git

cd "${REPO_ROOT}"

# ── Determine version range ───────────────────────────────────────────────────
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [[ -z "${LAST_TAG}" ]]; then
  log "No previous tag found — collecting all commits"
  COMMIT_RANGE="HEAD"
else
  log "Last tag: ${LAST_TAG}"
  COMMIT_RANGE="${LAST_TAG}..HEAD"
fi

# ── Collect commits by category ───────────────────────────────────────────────
declare -a FEATURES FIXES BREAKING CHORES DOCS OTHER

while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  if   [[ "$line" =~ ^feat(\(.*\))?!: ]];  then BREAKING+=("$line")
  elif [[ "$line" =~ ^fix(\(.*\))?!: ]];   then BREAKING+=("$line")
  elif [[ "$line" =~ ^feat(\(.*\))?: ]];   then FEATURES+=("$line")
  elif [[ "$line" =~ ^fix(\(.*\))?: ]];    then FIXES+=("$line")
  elif [[ "$line" =~ ^docs(\(.*\))?: ]];   then DOCS+=("$line")
  elif [[ "$line" =~ ^chore(\(.*\))?: ]] \
    || [[ "$line" =~ ^ci(\(.*\))?: ]] \
    || [[ "$line" =~ ^build(\(.*\))?: ]];  then CHORES+=("$line")
  else
    OTHER+=("$line")
  fi
done < <(git log "${COMMIT_RANGE}" --pretty=format:"%s" 2>/dev/null)

TOTAL=$(( ${#FEATURES[@]} + ${#FIXES[@]} + ${#BREAKING[@]} + ${#DOCS[@]} + ${#CHORES[@]} + ${#OTHER[@]} ))

if [[ "${TOTAL}" -eq 0 ]]; then
  log "No new commits found since ${LAST_TAG:-beginning}. Nothing to update."
  exit 0
fi

log "Found ${TOTAL} commit(s) to document."

# ── Determine next version placeholder ───────────────────────────────────────
if [[ -n "${NEXT_VERSION:-}" ]]; then
  VERSION_HEADER="## [${NEXT_VERSION}] - ${TODAY}"
else
  VERSION_HEADER="## [Unreleased] - ${TODAY}"
fi

# ── Build new changelog section ───────────────────────────────────────────────
build_section() {
  local title="$1"
  shift
  local -a items=("$@")
  if [[ ${#items[@]} -gt 0 ]]; then
    echo "### ${title}"
    for item in "${items[@]}"; do
      # Strip conventional commit prefix for readability
      local msg
      msg=$(echo "$item" | sed 's/^[a-z]*(.*): //' | sed 's/^[a-z]*: //')
      echo "- ${msg}"
    done
    echo ""
  fi
}

NEW_SECTION="${VERSION_HEADER}"
NEW_SECTION+=$'\n\n'

if [[ ${#BREAKING[@]} -gt 0 ]]; then
  NEW_SECTION+=$(build_section "⚠ Breaking Changes" "${BREAKING[@]}")
fi
if [[ ${#FEATURES[@]} -gt 0 ]]; then
  NEW_SECTION+=$(build_section "Features" "${FEATURES[@]}")
fi
if [[ ${#FIXES[@]} -gt 0 ]]; then
  NEW_SECTION+=$(build_section "Bug Fixes" "${FIXES[@]}")
fi
if [[ ${#DOCS[@]} -gt 0 ]]; then
  NEW_SECTION+=$(build_section "Documentation" "${DOCS[@]}")
fi
if [[ ${#CHORES[@]} -gt 0 ]]; then
  NEW_SECTION+=$(build_section "Chores" "${CHORES[@]}")
fi
if [[ ${#OTHER[@]} -gt 0 ]]; then
  NEW_SECTION+=$(build_section "Other" "${OTHER[@]}")
fi

# ── Write / update CHANGELOG.md ───────────────────────────────────────────────
if [[ ! -f "${CHANGELOG_PATH}" ]]; then
  log "Creating new ${CHANGELOG_FILE}"
  cat > "${CHANGELOG_PATH}" <<EOF
# Changelog

All notable changes to this project will be documented in this file.
This project adheres to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

${NEW_SECTION}
EOF
else
  log "Prepending new section to existing ${CHANGELOG_FILE}"
  TMPFILE=$(mktemp)
  # Insert new section after the first heading line (or at top if none)
  awk -v new_section="${NEW_SECTION}" '
    /^# / && !inserted {
      print
      print ""
      printf "%s", new_section
      inserted=1
      next
    }
    { print }
  ' "${CHANGELOG_PATH}" > "${TMPFILE}"

  # Fallback: if no top-level heading was found, prepend entirely
  if ! grep -q "${VERSION_HEADER}" "${TMPFILE}" 2>/dev/null; then
    { echo "${NEW_SECTION}"; cat "${CHANGELOG_PATH}"; } > "${TMPFILE}"
  fi

  mv "${TMPFILE}" "${CHANGELOG_PATH}"
fi

log "Changelog updated successfully → ${CHANGELOG_PATH}"
