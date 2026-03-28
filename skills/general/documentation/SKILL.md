---
name: documentation
description: Documentation standards for READMEs, code comments, and API docs. Use when writing or reviewing any project documentation.
---
# Documentation

## README Structure
A good README answers questions in this order:

1. **Name and description** — what the project is and what problem it solves (2–3 sentences)
2. **Quick start** — the fastest path from zero to running (3–5 commands max)
3. **Prerequisites** — required tools, runtimes, and versions
4. **Installation** — step-by-step setup for a new developer
5. **Usage** — common commands and workflows with real examples
6. **Configuration** — all environment variables and config options in a table
7. **Development** — how to run tests, linting, and the dev server
8. **Architecture** — a brief description of the main components and how they interact

## Writing Style
- Write for **someone new to the codebase** — assume no prior context
- Use **present tense**: "The server listens on port 3000", not "The server will listen"
- Every code example must be **complete and runnable** — copy-paste should work
- Keep paragraphs short; prefer **headings and lists** over dense prose
- Avoid jargon without defining it first

## Code Comments
**Comment the WHY, not the WHAT.**

```js
// Bad: increment the counter
counter++;

// Good: the counter tracks retries so we can back off after MAX_RETRIES
counter++;
```

Rules:
- Do not comment self-explanatory code — trust the reader to read the code
- **Do** comment non-obvious business rules, regulatory constraints, and performance decisions
- **Do** comment workarounds and hacks with a link to the relevant issue or ticket
- Keep comments **up to date** — a stale comment is worse than no comment
- Replace `TODO` comments with tracked issues; do not leave them in production code

## API Documentation
Every endpoint must document:

| Field | Description |
|---|---|
| Method + path | `GET /users/{id}` |
| Description | What this endpoint does |
| Path/query params | Name, type, required/optional, description |
| Request body | Schema with field descriptions and constraints |
| Success response | Status code + response schema |
| Error responses | All possible error codes and their meanings |
| Auth requirements | Which roles or scopes are required |

Always include a **working curl example**:

```bash
curl -X POST https://api.example.com/v1/users \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "name": "Alice"}'
```
