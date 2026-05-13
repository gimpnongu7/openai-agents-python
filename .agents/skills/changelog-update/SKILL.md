# Changelog Update Skill

Automatically maintains the project CHANGELOG.md based on merged PRs, commits, and version bumps.

## Overview

This skill analyzes recent git history and open/merged pull requests to generate or update changelog entries following the [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format.

## Triggers

- Manual invocation after a release or version bump
- After merging a PR tagged with `changelog` label
- Scheduled (e.g., before release preparation)

## What It Does

1. **Reads existing CHANGELOG.md** to understand current state and latest version
2. **Scans git log** for commits since the last changelog entry
3. **Categorizes changes** into Added, Changed, Deprecated, Removed, Fixed, Security
4. **Groups by PR** when available, falling back to individual commits
5. **Writes updated CHANGELOG.md** with a new `[Unreleased]` section or bumps to a specific version

## Categorization Rules

| Commit prefix / label | Section    |
|-----------------------|------------|
| `feat:`, `feature:`   | Added      |
| `fix:`, `bugfix:`     | Fixed      |
| `refactor:`, `perf:`  | Changed    |
| `deprecate:`          | Deprecated |
| `remove:`, `drop:`    | Removed    |
| `security:`, `sec:`   | Security   |
| `docs:`, `chore:`     | (skipped by default) |

## Configuration

Optional `.agents/skills/changelog-update/config.yaml`:

```yaml
skip_prefixes:
  - docs
  - chore
  - ci
include_authors: true
group_by_pr: true
target_file: CHANGELOG.md
```

## Output

Updates `CHANGELOG.md` in-place. Opens a PR or commits directly to the current branch depending on invocation context.

## Usage

```bash
bash .agents/skills/changelog-update/scripts/run.sh [--version 1.2.0] [--since v1.1.0]
```

### Arguments

- `--version` — tag the unreleased section with this version string
- `--since` — git ref to start scanning from (defaults to last git tag)
- `--dry-run` — print proposed changelog diff without writing

## Requirements

- `git` available in PATH
- `gh` CLI for PR metadata (optional but recommended)
- Python 3.9+ (used by the update script)
