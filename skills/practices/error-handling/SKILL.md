---
name: error-handling
description: Error handling patterns for consistent, meaningful error management across the stack. Use when implementing any feature that can fail.
---

# Error Handling

## Principles

- **Errors are expected, not exceptional.** Network calls fail. Users provide invalid input. Disks fill up. Treat failures as a normal part of the flow.
- **Handle errors at the right level.** The layer that has enough context to make a decision handles the error. Lower layers propagate with context; they do not swallow or silently ignore.
- **Provide context.** An error message of "failed" is useless. Include what operation failed, what the inputs were, and what the caller should do about it.
- **Don't swallow errors.** An empty `catch` block that continues execution as if nothing happened is a bug waiting to surface in production.

---

## At System Boundaries

System boundaries are where external data enters your system: HTTP requests, message queue consumers, CLI arguments, file uploads.

- **Validate all input** before it touches business logic. Check type, format, length, and allowed values.
- **Return structured error responses.** Clients need machine-readable error codes, not just human-readable messages.
  ```json
  { "error": "VALIDATION_FAILED", "field": "email", "message": "must be a valid email address" }
  ```
- **Never expose internal details** in error responses (stack traces, SQL errors, internal paths, system versions).
- **Log the full error internally.** The sanitized response goes to the client; the full context (stack trace, request ID, inputs) goes to your logging system.

---

## In Business Logic

Business logic is the core of your application. Errors here are domain events, not infrastructure surprises.

- **Use typed or custom errors.** A generic `Error` tells the caller nothing. `InsufficientFundsError`, `OrderAlreadyShippedError`, and `UserNotFoundError` convey meaning and can be handled selectively.
- **Propagate with context.** When rethrowing, wrap the original error:
  ```
  throw new PaymentProcessingError("failed to charge card", { cause: originalError, orderId })
  ```
- **Fail fast.** Validate preconditions at the start of a function. Don't let invalid state propagate deep into logic only to fail mysteriously later.
- **Make impossible states unrepresentable.** Use the type system to eliminate invalid combinations at compile time rather than checking for them at runtime.

---

## In Infrastructure Code

Infrastructure code talks to databases, external APIs, message queues, and file systems. These components fail transiently.

- **Retry transient failures with exponential backoff.** Network blips, rate limits, and momentary unavailability are retryable. Authorization errors and validation errors are not.
- **Use circuit breakers.** When a downstream service is consistently failing, stop hammering it. Open the circuit, return a fast failure, and allow time to recover.
- **Set timeouts on all external calls.** A call without a timeout can hang forever. Every network call, database query, and external service call needs an explicit timeout.
- **Degrade gracefully.** When a non-critical dependency fails (a recommendations service, an analytics call), the main flow should continue with reduced functionality rather than failing entirely.

---

## Anti-Patterns

Avoid these patterns — they make bugs harder to find and production incidents harder to diagnose.

| Anti-pattern | Why it's harmful |
|---|---|
| **Empty catch block** | Silently discards the error. The program continues in an invalid state. |
| **Catch-and-rethrow without context** | Loses the original error message and stack trace. |
| **Returning `null` or `undefined` for failure** | Forces every caller to remember to check, and they often won't. |
| **Log-and-throw** | Produces duplicate log entries and confusing stack traces. Log or throw, not both. |
| **Generic error messages** | "Something went wrong" is not actionable for users or on-call engineers. |
| **Catching `Error` to ignore specific errors** | Catches too broadly; suppresses unexpected errors alongside the expected one. |
