---
name: release
description: Automated release workflow — version bump from conventional commits, changelog generation, tagging, and optional push. Use when a project is ready to cut a release.
---

# Release

Handles the full release pipeline: detect project type, determine version bump from commit history, generate changelog, update version files, commit, tag, and optionally push.

## When to Apply

- User says "release", "cut a release", "bump version", "publish", "tag a release"
- After Reviewer passes and human approves the final output
- Impl Coordinator or Infra lead initiating a release after implementation is complete

## Process

### Step 1: Detect Project Type

Check which version file exists (first match wins):

| File | Ecosystem | Version Location |
|------|-----------|-----------------|
| `package.json` | Node.js | `.version` field |
| `pyproject.toml` | Python | `[project].version` or `[tool.poetry].version` |
| `Cargo.toml` | Rust | `[package].version` |
| `go.mod` | Go | git tags only (no version file) |
| `.claude-plugin/plugin.json` | Claude Plugin | `.version` field |
| `VERSION` or `version.txt` | Generic | file contents |

If no version file is found, ask the user which ecosystem this is.

### Step 2: Get Current Version

Read the current version from the detected file. If no version exists yet, start at `0.0.0`.

Find the last git tag matching `v*` pattern:
```bash
git describe --tags --abbrev=0 --match "v*" 2>/dev/null
```

If no tag exists, use all commits.

### Step 3: Analyze Commits Since Last Release

Read commits since the last tag:
```bash
git log <last-tag>..HEAD --pretty=format:"%s" --no-merges
```

Parse each commit using conventional commit format (`type: description` or `type(scope): description`):

| Commit Type | Semver Bump | Changelog Section |
|-------------|-------------|-------------------|
| `feat:` | minor | Added |
| `fix:` | patch | Fixed |
| `refactor:` | patch | Changed |
| `perf:` | patch | Performance |
| `docs:` | none | Documentation |
| `test:` | none | Testing |
| `chore:` | none | Maintenance |
| `BREAKING CHANGE` in body or `!` after type | major | Breaking Changes |

The highest bump wins: if any commit is major → major. If any is minor → minor. Otherwise patch.

### Step 4: Propose Version

Calculate the new version from current + bump type. Present to the user:

```
Current version: 1.2.3
Commits since v1.2.3: 8 (3 feat, 4 fix, 1 refactor)
Proposed bump: minor → 1.3.0

Proceed? (yes/no/major/minor/patch to override)
```

Wait for user confirmation. Do not proceed without it.

### Step 5: Generate Changelog

Generate a changelog entry for the new version. Prepend to `CHANGELOG.md` (create if it doesn't exist).

Format:
```markdown
## [1.3.0] - 2026-03-28

### Breaking Changes
- Description of breaking change

### Added
- feat: description ([abc1234])
- feat(scope): description ([def5678])

### Fixed
- fix: description ([aaa1111])

### Changed
- refactor: description ([bbb2222])

### Performance
- perf: description ([ccc3333])
```

Rules:
- Include the short commit hash in brackets
- Group by type, ordered: Breaking Changes → Added → Fixed → Changed → Performance
- Skip sections with no entries
- Keep entries concise — use the commit message as-is

### Step 6: Update Version Files

Update the version in the detected file(s):

- `package.json`: update `.version` field. Also update `package-lock.json` if it exists (run `npm install --package-lock-only` or equivalent).
- `pyproject.toml`: update the version field
- `Cargo.toml`: update `[package].version`, then run `cargo check` to update `Cargo.lock`
- `.claude-plugin/plugin.json`: update `.version` field
- `VERSION`/`version.txt`: overwrite file contents

### Step 7: Commit, Tag, Push

```bash
git add -A
git commit -m "release: v1.3.0"
git tag -a "v1.3.0" -m "Release v1.3.0"
```

Then ask the user:
```
Release v1.3.0 committed and tagged locally.
Push to remote? (yes/no)
```

If yes:
```bash
git push origin main --follow-tags
```

### Step 8: Summary

Report what was done:
```
Release v1.3.0 complete.
- Version bumped: 1.2.3 → 1.3.0 (minor)
- Changelog updated: CHANGELOG.md
- Commits included: 8
- Tag: v1.3.0
- Pushed: yes/no
```

## Flags

| Flag | Effect |
|------|--------|
| `--dry-run` | Show what would happen without making changes |
| `--major` | Force major bump regardless of commits |
| `--minor` | Force minor bump |
| `--patch` | Force patch bump |
| `--no-push` | Skip the push prompt, don't push |

## Rules

- CRITICAL: Always confirm with the user before committing the release
- CRITICAL: Never push without explicit user approval
- HIGH: If there are uncommitted changes in the working tree, abort and tell the user to commit or stash first
- HIGH: If there are no new commits since the last tag, abort — nothing to release
- MEDIUM: If `CHANGELOG.md` already has an entry for this version, warn and ask before overwriting
- MEDIUM: Run project tests before releasing if a test command is configured — abort if tests fail
