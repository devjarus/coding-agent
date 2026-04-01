---
name: redis-specialist
description: Redis expertise — caching patterns, session management, pub/sub, data structures, TTL strategies, memory optimization, and persistence configuration.
---

# Redis Specialist

Data structure selection, caching patterns, TTL strategy, memory optimization, and operational configuration.

## When to Apply

- Implementing caching layers (cache-aside, write-through, invalidation)
- Designing session storage or distributed locks
- Choosing Redis data structures for specific use cases
- Setting up pub/sub or stream-based messaging
- Optimizing memory usage or configuring eviction policies
- Implementing rate limiting or idempotency patterns

## Core Expertise (rules/core-expertise.md)

- Data structures: Strings, Hashes, Lists, Sets, Sorted Sets, Streams, HyperLogLog, Bitmaps, Geospatial
- Caching patterns: cache-aside, write-through, write-behind, read-through, TTL/event invalidation
- Sessions as Hashes with TTL; distributed locks via `SET NX PX`; rate limiting with sorted sets
- Pub/Sub for fan-out; Streams for durable messaging with consumer groups
- Memory: `maxmemory` + eviction policy required; no values >1MB; RDB+AOF for production

## Coding Patterns (rules/coding-patterns.md)

- Key naming: `{service}:{entity}:{id}` convention
- Cache-aside: check cache -> miss -> load from DB -> populate with TTL
- Distributed lock: `SET NX PX` + Lua script for atomic release
- Sliding window rate limiter with sorted sets + pipeline
- Graceful degradation wrapper for Redis unavailability

## Rules

1. **Follow the project's Redis client** -- match existing patterns for connection pooling and error handling
2. **TTL is mandatory** -- every key must have a TTL; no unbounded cache growth
3. **No large values** -- keep under 1 MB; store only IDs for larger payloads
4. **Use Context7 MCP for documentation lookup**
5. **Test cache behavior** -- cover hit, miss, TTL expiry, and eviction scenarios
6. **Graceful degradation is required** -- app must continue when Redis is down

## Skills

- **integration-testing** -- database integration test patterns
- **security-checklist** -- connection strings from env vars only, no sensitive data in logs
