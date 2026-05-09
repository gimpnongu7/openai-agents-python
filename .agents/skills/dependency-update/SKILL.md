# Dependency Update Skill

Automatically checks for outdated dependencies and creates pull requests with version bumps.

## Overview

This skill scans the project's dependency files (`pyproject.toml`, `requirements.txt`, etc.) and identifies packages that have newer versions available. It then creates a branch and PR with the updated versions, including a summary of changes.

## Triggers

- Scheduled: Weekly on Mondays at 09:00 UTC
- Manual: Can be triggered via workflow dispatch

## What It Does

1. **Scans** all dependency files in the repository
2. **Checks** each dependency against PyPI for newer versions
3. **Filters** updates by type:
   - `patch` — safe, auto-merge eligible
   - `minor` — requires review
   - `major` — requires manual approval
4. **Creates** a branch `deps/auto-update-YYYY-MM-DD`
5. **Opens** a PR with a structured description of all changes
6. **Labels** the PR based on the severity of version bumps

## Configuration

The skill reads from `.agents/skills/dependency-update/config.yaml` if present.

```yaml
# Example config
auto_merge: patch        # patch | minor | major | none
exclude:
  - some-pinned-package
groups:
  - name: "Testing"
    patterns: ["pytest*", "coverage*"]
```

## Output

The skill produces:
- A PR with all dependency bumps
- A comment summarizing the changelog highlights for each updated package
- Labels: `dependencies`, `auto-update`, and one of `patch-update` / `minor-update` / `major-update`

## Requirements

- Python 3.9+
- `pip-audit` for security checks (optional but recommended)
- GitHub token with `pull_requests: write` and `contents: write` permissions

## Notes

- The skill will not update packages that are pinned with `==` unless explicitly configured
- Security vulnerabilities from `pip-audit` are always flagged regardless of version bump type
- If no updates are found, no PR is created and the workflow exits cleanly
