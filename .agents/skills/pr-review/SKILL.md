# PR Review Skill

Automatically reviews pull requests for code quality, consistency, and potential issues.

## What it does

- Analyzes changed files in a pull request
- Checks for code style and consistency issues
- Identifies potential bugs or anti-patterns
- Verifies tests are included for new functionality
- Ensures documentation is updated when needed
- Posts a structured review comment summarizing findings

## When to use

Trigger this skill when:
- A new pull request is opened
- A pull request is updated with new commits
- A manual review is requested via comment (`/review`)

## Inputs

| Variable | Description | Required |
|----------|-------------|----------|
| `PR_NUMBER` | The pull request number to review | Yes |
| `REPO` | Repository in `owner/repo` format | Yes |
| `GITHUB_TOKEN` | GitHub token with PR read/write access | Yes |
| `OPENAI_API_KEY` | OpenAI API key for analysis | Yes |
| `BASE_BRANCH` | Base branch to diff against (default: `main`) | No |
| `REVIEW_FOCUS` | Comma-separated focus areas (e.g. `security,performance`) | No |

## Outputs

Posts a review comment on the PR with:
- **Summary**: High-level overview of changes
- **Issues**: List of potential problems with severity (error/warning/info)
- **Suggestions**: Actionable improvement recommendations
- **Checklist**: Standard review checklist with pass/fail status

## Configuration

Customize review behavior via `.agents/skills/pr-review/config.yaml`:

```yaml
review:
  # Severity threshold to block merge (error, warning, none)
  block_on: error
  # Max number of issues to report per file
  max_issues_per_file: 10
  # File patterns to skip during review
  ignore_patterns:
    - "*.lock"
    - "dist/**"
    - "*.min.js"
  # Custom rules to enforce
  rules:
    require_tests: true
    require_docstrings: true
    max_file_length: 500
```

## Example review output

```
## 🤖 Automated PR Review

### Summary
This PR adds a new authentication module with JWT support. 3 files changed, +120/-15 lines.

### Issues Found

❌ **[ERROR]** `src/auth.py:45` — Hardcoded secret key detected. Use environment variable instead.
⚠️  **[WARNING]** `src/auth.py:78` — Missing error handling for expired token case.
ℹ️  **[INFO]** `tests/test_auth.py` — Consider adding edge case tests for empty token input.

### Checklist
- [x] Tests included
- [x] Documentation updated
- [ ] No hardcoded secrets
- [x] Type hints present
- [x] No unused imports
```

## Notes

- Reviews are non-blocking by default unless `block_on` is configured
- The skill uses the diff context to avoid reviewing unchanged code
- Large PRs (>50 files) are reviewed in batches to stay within token limits
