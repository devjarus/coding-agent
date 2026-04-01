---
name: security-checklist
description: Security review checklist for code review and implementation. Covers OWASP top 10, authentication, data protection, and common vulnerabilities.
---

# Security Checklist

Use this checklist during code review and before marking any feature complete. Work through each section systematically.

---

## Input Handling

- [ ] All input is validated for correct type, length, and format before use
- [ ] HTML output is sanitized to prevent XSS (encode `<`, `>`, `&`, `"`, `'`)
- [ ] SQL queries use parameterized statements or prepared queries — no string concatenation
- [ ] Shell commands use parameterized execution — no string interpolation of user data
- [ ] File paths are sandboxed to an allowed directory (no `../` traversal)
- [ ] File uploads validate MIME type, extension, and file size — content is inspected, not just the name
- [ ] URL redirects use an allowlist of valid destinations — open redirects are blocked

---

## Authentication & Authorization

- [ ] All protected endpoints require authentication
- [ ] Authorization is enforced at the resource level — ownership is verified, not just login status
  - Example: a user can fetch `/api/orders/123` only if order 123 belongs to them
- [ ] Passwords are hashed with `bcrypt` or `argon2` — never `md5`, `sha1`, or unsalted hashes
- [ ] Sessions have an expiration time and are invalidated on logout
- [ ] Login endpoints have rate limiting and account lockout after repeated failures
- [ ] Password reset tokens are single-use, short-lived, and cryptographically random

---

## Data Protection

- [ ] No secrets, API keys, or credentials are hardcoded in source code or config files
- [ ] Secrets are loaded from environment variables or a secrets manager
- [ ] Sensitive data at rest is encrypted (PII, payment data, health data)
- [ ] All data in transit uses TLS — no plaintext HTTP for sensitive endpoints
- [ ] PII is not written to logs (no emails, names, SSNs, or payment details in log lines)
- [ ] Database connections use TLS

---

## API Security

- [ ] CORS policy is as restrictive as possible — explicitly listed origins, not `*`
- [ ] CSRF protection is active on all state-mutating endpoints (POST, PUT, PATCH, DELETE)
- [ ] Error responses do not expose internal details (stack traces, DB errors, internal paths)
- [ ] Rate limiting is applied to public-facing endpoints
- [ ] Request body size limits are enforced to prevent resource exhaustion
- [ ] Sensitive operations require re-authentication (e.g., changing email, deleting account)

---

## Dependencies

- [ ] No dependencies have known critical or high-severity CVEs
- [ ] All dependencies come from trusted, official registries
- [ ] Dependency versions are pinned (or lock files are committed) for reproducible builds
- [ ] Unused dependencies have been removed

---

## LLM / AI-Specific Security

- [ ] User input is never concatenated directly into LLM prompts without sanitization — use structured message formats, not string templates
- [ ] LLM API keys are in environment variables, not in client-side code or committed files
- [ ] Token limits (`max_tokens`) are set on every LLM call — no unbounded generation
- [ ] Cost budgets exist per user/session — a single user cannot trigger unlimited API spend
- [ ] Agent loops have a max iteration limit — prevent infinite tool-calling loops
- [ ] LLM output is validated/sanitized before rendering as HTML, executing as code, or using in database queries
- [ ] Tool permissions are scoped — each agent only has the tools it needs (principle of least privilege)
- [ ] Sensitive data (PII, secrets) is not included in LLM prompts or stored in conversation logs
- [ ] Rate limiting is applied to LLM-powered endpoints (they are expensive, making them DoS targets)

---

## Common Vulnerabilities Reference

| Vulnerability | Defense |
|---|---|
| **SQL Injection** | Use parameterized queries or an ORM. Never concatenate user input into SQL strings. |
| **XSS (Cross-Site Scripting)** | Encode output for the rendering context. Use a templating engine that auto-escapes. |
| **Path Traversal** | Resolve and validate paths against an allowlisted base directory. Reject inputs containing `..`. |
| **Command Injection** | Use APIs that accept argument arrays, not shell strings. Never pass user input to `exec`/`system`. |
| **SSRF (Server-Side Request Forgery)** | Validate and allowlist destination URLs for outbound requests. Block access to internal IP ranges. |
| **Insecure Deserialization** | Validate and sanitize data before deserializing. Avoid deserializing untrusted data into objects. |
| **Broken Access Control** | Check ownership and permissions on every data access, not just at the route level. |
| **Security Misconfiguration** | Disable debug modes in production. Remove default credentials. Apply least-privilege to service accounts. |
