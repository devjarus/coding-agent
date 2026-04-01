# Redis Core Expertise

## Data Structures
- **Strings** -- simple key/value, counters (`INCR`/`DECR`/`INCRBY`), serialized JSON blobs
- **Hashes** -- object representations where fields are accessed individually; more memory-efficient than JSON strings
- **Lists** -- ordered sequences, queues (`RPUSH`/`LPOP`), stacks (`RPUSH`/`RPOP`), capped feeds (`LTRIM`)
- **Sets** -- unordered unique members; union/intersection/difference; membership tests (`SISMEMBER`)
- **Sorted Sets** -- ranked leaderboards, priority queues, range-by-score lookups
- **Streams** -- append-only log with consumer groups; reliable event queues with at-least-once delivery
- **HyperLogLog** -- probabilistic cardinality estimation for large unique-count problems
- **Bitmaps** -- bit-level operations; compact per-user boolean flags
- **Geospatial** -- `GEOADD`/`GEODIST`/`GEORADIUS` for location-based data

## Caching Patterns
- **Cache-aside (lazy loading)** -- check cache first; on miss, load from DB, write to cache with TTL
- **Write-through** -- write to cache and DB simultaneously on every mutation
- **Write-behind** -- write to cache immediately, persist to DB asynchronously
- **Read-through** -- cache layer fetches from DB on miss transparently
- **TTL invalidation** -- set TTL on every cache entry; never cache without a TTL
- **Event-driven invalidation** -- publish cache-bust events on write for strong consistency

## Sessions & Distributed Coordination
- Store session data as Hashes keyed by session ID; set TTL equal to session expiry
- Distributed locks with `SET key value NX PX milliseconds` or Redlock algorithm
- Sliding-window rate limiting with sorted sets in `MULTI`/`EXEC` or Lua script
- `SETNX` / `SET NX` for idempotency keys

## Pub/Sub & Messaging
- `PUBLISH`/`SUBSCRIBE` for fire-and-forget fan-out; no persistence
- Streams (`XADD`/`XREADGROUP`/`XACK`) for durable messaging with consumer groups
- `BLPOP`/`BRPOP` for simple blocking work queues
- Monitor `XPENDING` to detect stuck consumers

## Memory Management & Operations
- Always set `maxmemory` with eviction policy: `allkeys-lru` for caches, `volatile-lru` for mixed-use, `noeviction` for durable stores
- Monitor with `INFO memory`; watch `used_memory_rss` vs `used_memory` for fragmentation
- Avoid values larger than 1 MB
- Use `OBJECT ENCODING key` to verify compact encoding
- Persistence: RDB snapshots + AOF combined recommended for production
- High availability: Redis Sentinel for failover; Redis Cluster for horizontal sharding
