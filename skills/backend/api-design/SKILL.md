---
name: api-design
description: REST API design conventions covering URL structure, HTTP methods, response formats, status codes, pagination, and versioning. Use when designing or reviewing API endpoints.
---
# API Design

## URL Structure
- Use nouns, never verbs: `/users`, not `/getUsers`
- Always plural: `/orders`, `/products`
- Nest resources max 2 levels deep: `/users/{id}/orders` is fine; avoid `/users/{id}/orders/{id}/items/{id}`
- Use kebab-case for multi-word segments: `/blog-posts`, `/user-profiles`

## HTTP Methods
| Method | Semantics |
|--------|-----------|
| GET | Read resource(s), idempotent, no body |
| POST | Create a new resource or trigger an action |
| PUT | Replace a resource entirely |
| PATCH | Partial update of a resource |
| DELETE | Remove a resource, idempotent |

## Response Format
**Success:**
```json
{
  "data": { ... },
  "meta": { "requestId": "abc123", "timestamp": "2024-01-01T00:00:00Z" }
}
```

**Error:**
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable description",
    "details": [{ "field": "email", "issue": "Invalid format" }]
  }
}
```

## Status Codes
| Code | When to use |
|------|-------------|
| 200 | Successful GET, PUT, PATCH |
| 201 | Successful POST that created a resource |
| 204 | Successful DELETE or action with no response body |
| 400 | Bad request — malformed syntax or invalid parameters |
| 401 | Not authenticated |
| 403 | Authenticated but not authorized |
| 404 | Resource not found |
| 409 | Conflict — duplicate, state mismatch |
| 422 | Validation failed — well-formed but semantically invalid |
| 500 | Unexpected server error |

## Pagination
**Cursor-based** (for large or frequently updated datasets):
```json
{
  "data": [...],
  "meta": {
    "nextCursor": "eyJpZCI6MTAwfQ==",
    "hasMore": true
  }
}
```

**Offset-based** (for simple, small datasets):
```json
{
  "data": [...],
  "meta": {
    "total": 250,
    "page": 2,
    "perPage": 25,
    "totalPages": 10
  }
}
```

Always return a `meta` object even when there is only one page.

## Versioning
- Major breaking changes: URL prefix — `/v1/users`, `/v2/users`
- Additive changes (new optional fields, new endpoints) are backward compatible and do not require a version bump
- Deprecate old versions with `Sunset` response headers before removing
