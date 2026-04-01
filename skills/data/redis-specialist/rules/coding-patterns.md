# Redis Coding Patterns

## Key Naming Convention
```
{service}:{entity}:{id}
{service}:{entity}:{id}:{field}

# Examples
auth:session:abc123
catalog:product:42:views
ratelimit:api:user:99:2024-03-27T14
leaderboard:game:weekly
```

## Cache-Aside Pattern
```typescript
async function getProduct(id: string): Promise<Product> {
  const cacheKey = `catalog:product:${id}`;

  // 1. Check cache
  const cached = await redis.get(cacheKey);
  if (cached) return JSON.parse(cached);

  // 2. Cache miss -- load from DB
  const product = await db.products.findById(id);
  if (!product) throw new NotFoundError(`Product ${id} not found`);

  // 3. Populate cache with TTL
  await redis.set(cacheKey, JSON.stringify(product), 'EX', 300); // 5 min TTL

  return product;
}
```

## Distributed Lock Pattern
```typescript
async function withLock<T>(
  key: string,
  ttlMs: number,
  fn: () => Promise<T>
): Promise<T> {
  const lockKey = `lock:${key}`;
  const token = crypto.randomUUID();

  const acquired = await redis.set(lockKey, token, 'NX', 'PX', ttlMs);
  if (!acquired) throw new LockConflictError(`Failed to acquire lock: ${key}`);

  try {
    return await fn();
  } finally {
    // Release only if we still own the lock (Lua for atomicity)
    const release = `
      if redis.call("get", KEYS[1]) == ARGV[1] then
        return redis.call("del", KEYS[1])
      else
        return 0
      end
    `;
    await redis.eval(release, 1, lockKey, token);
  }
}
```

## Sliding Window Rate Limiter
```typescript
async function isRateLimited(
  userId: string,
  windowSec: number,
  limit: number
): Promise<boolean> {
  const key = `ratelimit:api:user:${userId}`;
  const now = Date.now();
  const windowStart = now - windowSec * 1000;

  const pipeline = redis.pipeline();
  pipeline.zremrangebyscore(key, 0, windowStart);
  pipeline.zadd(key, now, `${now}-${Math.random()}`);
  pipeline.zcard(key);
  pipeline.expire(key, windowSec);

  const results = await pipeline.exec();
  const count = results[2][1] as number;
  return count > limit;
}
```

## Graceful Degradation Wrapper
```typescript
async function withRedisFallback<T>(
  operation: () => Promise<T>,
  fallback: () => Promise<T>
): Promise<T> {
  try {
    return await operation();
  } catch (err) {
    if (err instanceof RedisConnectionError) {
      logger.warn('Redis unavailable, falling through to primary store');
      return fallback();
    }
    throw err;
  }
}
```
