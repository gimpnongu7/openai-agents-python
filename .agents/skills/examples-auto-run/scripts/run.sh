#!/usr/bin/env bash
# examples-auto-run skill script
# Discovers and runs all examples in the repository, reporting pass/fail status

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
EXAMPLES_DIR="${EXAMPLES_DIR:-examples}"
TIMEOUT="${EXAMPLE_TIMEOUT:-60}"
PYTHON="${PYTHON:-python}"
FAIL_FAST="${FAIL_FAST:-false}"
SKIP_PATTERNS="${SKIP_PATTERNS:-}"

# ─── Colour helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[PASS]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[FAIL]${NC}  $*"; }

# ─── Dependency checks ────────────────────────────────────────────────────────
check_dependencies() {
  local missing=0
  for cmd in "$PYTHON" timeout; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "Required command not found: $cmd"
      missing=1
    fi
  done
  [[ $missing -eq 0 ]] || exit 1
}

# ─── Example discovery ────────────────────────────────────────────────────────
discover_examples() {
  if [[ ! -d "$EXAMPLES_DIR" ]]; then
    log_error "Examples directory not found: $EXAMPLES_DIR"
    exit 1
  fi

  # Find all top-level Python files and subdirectory entry points
  find "$EXAMPLES_DIR" -maxdepth 2 -name '*.py' \
    | sort \
    | grep -v '__pycache__' \
    | grep -v '__init__'
}

# ─── Skip logic ───────────────────────────────────────────────────────────────
should_skip() {
  local file="$1"
  [[ -z "$SKIP_PATTERNS" ]] && return 1

  IFS=',' read -ra patterns <<< "$SKIP_PATTERNS"
  for pattern in "${patterns[@]}"; do
    if [[ "$file" == *"$pattern"* ]]; then
      return 0
    fi
  done
  return 1
}

# ─── Run a single example ─────────────────────────────────────────────────────
run_example() {
  local file="$1"
  local output
  local exit_code=0

  output=$(timeout "$TIMEOUT" "$PYTHON" "$file" 2>&1) || exit_code=$?

  if [[ $exit_code -eq 124 ]]; then
    log_warn "$(basename "$file") — timed out after ${TIMEOUT}s"
    return 2
  elif [[ $exit_code -ne 0 ]]; then
    log_error "$(basename "$file") — exited with code $exit_code"
    echo "$output" | sed 's/^/    /'
    return 1
  else
    log_ok "$(basename "$file")"
    return 0
  fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  check_dependencies

  log_info "Discovering examples in '${EXAMPLES_DIR}'…"
  mapfile -t examples < <(discover_examples)

  if [[ ${#examples[@]} -eq 0 ]]; then
    log_warn "No examples found in '${EXAMPLES_DIR}'"
    exit 0
  fi

  log_info "Found ${#examples[@]} example(s). Timeout: ${TIMEOUT}s each."
  echo

  local passed=0 failed=0 skipped=0 timed_out=0

  for example in "${examples[@]}"; do
    if should_skip "$example"; then
      log_warn "$(basename "$example") — skipped (matches SKIP_PATTERNS)"
      (( skipped++ )) || true
      continue
    fi

    run_example "$example"
    rc=$?

    case $rc in
      0) (( passed++ ))    || true ;;
      2) (( timed_out++ )) || true ;;
      *) (( failed++ ))    || true
         [[ "$FAIL_FAST" == "true" ]] && { log_error "Stopping early (FAIL_FAST=true)"; break; } ;;
    esac
  done

  echo
  log_info "Results: ${passed} passed | ${failed} failed | ${timed_out} timed out | ${skipped} skipped"

  if [[ $failed -gt 0 || $timed_out -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
