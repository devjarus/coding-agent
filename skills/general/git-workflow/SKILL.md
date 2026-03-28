---
name: git-workflow
description: Git branching strategy, commit conventions, commit frequency, and PR practices. Use when starting feature work, writing commit messages, or preparing a pull request.
---
# Git Workflow

## Branching
- `main` is **always deployable** — never commit broken code directly to it
- Create short-lived branches for all work: `feat/add-user-export`, `fix/login-redirect`, `chore/upgrade-deps`
- Delete branches after they are merged
- Rebase on main regularly to avoid large merge conflicts at PR time

## Commit Conventions
Use the **Conventional Commits** format:

```
<type>(<optional scope>): <short summary>

<optional body — explain WHY, not what>
```

| Type | When to use |
|------|-------------|
| `feat` | New feature visible to users |
| `fix` | Bug fix |
| `refactor` | Code change that is neither a feature nor a fix |
| `test` | Adding or updating tests |
| `docs` | Documentation only |
| `chore` | Build tooling, dependency updates, config |

Rules:
- Summary line **under 72 characters**
- Use the **imperative mood**: "add user export" not "added user export"
- The body explains **why** the change was made, not what the diff shows
- Each commit represents **one logical change** — do not bundle unrelated work

## Commit Frequency
Commit:
- After each test passes
- Before switching context to another task
- Whenever the codebase is in a working (even if incomplete) state
- Never leave uncommitted work at the end of a session

Small, frequent commits make bisecting bugs trivial and revert safe.

## Pull Requests
- One PR = one concern; do not mix feature work with refactors or dependency updates
- PR description must explain the **problem being solved** and the **approach taken**, not just list the changes
- **Self-review** the diff before requesting review — catch obvious issues yourself first
- Use **squash merge** to keep the main branch history clean and linear
- Link related issues in the description with `Closes #123`
