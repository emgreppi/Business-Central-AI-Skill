---
name: writing-git-commits
description: Writes git commit messages with proper format, type prefixes (feat/fix/chore), and imperative mood. Use when committing changes, writing a commit message, formatting commit text, or asking how to commit code properly.
license: MIT
metadata:
  version: 1.0.0
---

# Skill: Git Commit Message Rules

## Validation Gates

1. **Subject**: Type prefix present, imperative mood, max 72 chars
2. **Body/Footer**: Only if explicitly requested by user
3. **Final**: No past tense, no generic messages, no file names in subject

## Basic Rules

| Property | Value |
|----------|-------|
| **Language** | English |
| **Subject max** | 72 characters |
| **Tone** | Imperative ("add", "fix", not "added", "fixed") |

## Allowed Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New features | `feat: add purchase order support` |
| `fix` | Bug fixes | `fix: resolve user login issue` |
| `chore` | Non-feature (build, config) | `chore: rename rental file` |
| `refactor` | Code refactoring | `refactor: simplify rent logic` |
| `deploy` | Deployment changes | `deploy: trigger deployment` |
| `docs` | Documentation only | `docs: update starting guide` |

## Subject Line Format

```text
<type>: <short description in imperative mood>
```

**Examples:**
- `feat: add customer validation on save`
- `fix: correct tax amount calculation`
- `refactor: extract logic to helper codeunit`

## Body (only if requested)

- Do NOT include by default
- Explain **why** and **how**, not just what
- Wrap at ~72–100 chars

```text
feat: add automatic token refresh for API calls

- Tokens cached with expiration tracking
- Auto-refresh 5 minutes before expiry
- Fallback to re-authentication if refresh fails
```

## Footer (only if requested)

- **BREAKING CHANGE:** describe what changed
- Issue refs: `Refs: #123`, `Closes: #456`

```text
feat: change API endpoint structure

BREAKING CHANGE: API endpoints now require version prefix.
Old: /api/customers → New: /api/v2.0/customers

Refs: #456
```

## Quick Reference

**Minimum (default):**
```text
feat: add customer export functionality
```

**With body:**
```text
feat: add customer export functionality

Implements CSV export with date range filtering.
```

**With footer:**
```text
fix: resolve duplicate entry error

Closes: #790
```

## Do NOT

- Use past tense ("added", "fixed")
- Exceed 72 characters in subject
- Include body/footer unless requested
- Use generic messages ("fix bug", "update code")
- Include file names in subject
