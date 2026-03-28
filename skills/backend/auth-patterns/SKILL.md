---
name: auth-patterns
description: Authentication and authorization patterns covering session-based auth, JWT, OAuth 2.0, RBAC, and security best practices. Use when implementing login flows, protecting endpoints, or handling user identity.
---
# Auth Patterns

## Authentication

### Session-Based
- Store session ID in an `httpOnly`, `Secure`, `SameSite=Lax` cookie
- Back sessions with Redis (preferred) or a DB table
- Set a reasonable TTL (e.g., 24h idle, 30d absolute)
- Rotate session ID on privilege escalation (login, role change)

### Token-Based (JWT)
- Short-lived access token: **15 minutes**
- Long-lived refresh token: **7–30 days**
- Never store tokens in `localStorage` — use `httpOnly` cookies or keep the access token in memory only
- Sign with RS256 (asymmetric) for services that only verify; HS256 is fine for single-service use
- Validate `iss`, `aud`, `exp`, and `nbf` claims on every request
- Refresh token rotation: issue a new refresh token each time one is used; invalidate the old one

### OAuth 2.0
- Use the **Authorization Code flow with PKCE** for all client-facing apps
- Validate the `state` parameter to prevent CSRF
- Exchange the authorization code server-side — never expose client secrets to the browser
- Map the external identity to an internal user record on first login; store the provider ID

## Authorization

### Role-Based Access Control (RBAC)
- Assign roles to users (e.g., `admin`, `editor`, `viewer`)
- Check role at the endpoint/handler level before executing business logic
- Store role assignments in the DB; cache in the session/token but re-verify on sensitive actions

### Resource-Based Authorization
- Always verify that the authenticated user owns or has explicit access to the requested resource
- Never rely on URL obscurity (e.g., a UUID in the URL is not access control)
- Example check: `if (resource.ownerId !== req.user.id) return 403`

## Security Practices
- Hash passwords with **bcrypt** (cost 12+) or **argon2id**
- Rate limit auth endpoints: **5 attempts per minute** per IP and per account
- Apply temporary lockout (e.g., 15 minutes) after repeated failures
- Invalidate all active sessions when a user changes their password
- Use **constant-time comparison** for tokens and secrets (e.g., `crypto.timingSafeEqual`)
- Log all auth events (login success/failure, logout, password change, token refresh) with IP and user agent
- Never log passwords, tokens, or secrets
