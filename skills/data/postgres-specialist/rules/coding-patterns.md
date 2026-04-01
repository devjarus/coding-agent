# Postgres Coding Patterns

## Table Definition Template
```sql
CREATE TABLE table_name (
  id          BIGSERIAL      PRIMARY KEY,
  public_id   UUID           NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  -- domain columns here
  created_at  TIMESTAMPTZ    NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ    NOT NULL DEFAULT now()
);

-- Keep updated_at current automatically
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_table_name_updated_at
  BEFORE UPDATE ON table_name
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

## Safe Non-Nullable Column Backfill
```sql
-- Step 1: add nullable
ALTER TABLE table_name ADD COLUMN new_col TEXT;

-- Step 2: backfill in batches (run outside migration if table is large)
UPDATE table_name SET new_col = 'default_value' WHERE new_col IS NULL;

-- Step 3: enforce constraint
ALTER TABLE table_name ALTER COLUMN new_col SET NOT NULL;
```

## Concurrent Index Creation
```sql
-- Always use CONCURRENTLY in production
CREATE INDEX CONCURRENTLY idx_table_name_column
  ON table_name (column);

-- Partial index example
CREATE INDEX CONCURRENTLY idx_orders_pending
  ON orders (created_at)
  WHERE status = 'pending';
```

## CTE-Based Query Pattern
```sql
WITH recent_orders AS (
  SELECT user_id, COUNT(*) AS order_count, SUM(total_cents) AS total_cents
  FROM orders
  WHERE created_at >= now() - INTERVAL '30 days'
  GROUP BY user_id
),
ranked AS (
  SELECT *, RANK() OVER (ORDER BY total_cents DESC) AS spending_rank
  FROM recent_orders
)
SELECT u.email, r.order_count, r.total_cents, r.spending_rank
FROM ranked r
JOIN users u ON u.id = r.user_id
WHERE r.spending_rank <= 100;
```
