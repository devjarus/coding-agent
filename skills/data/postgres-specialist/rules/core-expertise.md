# Postgres Core Expertise

## Schema Design
- Apply normalization (1NF-3NF) by default; denormalize deliberately with documented justification
- Enforce data integrity at the database level: `NOT NULL`, `UNIQUE`, `CHECK`, and `FOREIGN KEY` constraints
- Add `created_at TIMESTAMPTZ NOT NULL DEFAULT now()` and `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()` to every table
- Use `SERIAL`/`BIGSERIAL` for internal PKs; `UUID` for public-facing IDs
- Choose types: `TEXT` over `VARCHAR(n)` unless length matters, `NUMERIC` for money, `TIMESTAMPTZ` always
- Model many-to-many with explicit join tables carrying timestamps and metadata

## Migrations
- Every migration must be reversible -- write both `up` and `down`
- Safe backfill sequence for non-nullable columns: add NULLABLE -> backfill in batches -> add NOT NULL
- Never lock tables unnecessarily: use `CREATE INDEX CONCURRENTLY`, `ALTER TABLE ... VALIDATE CONSTRAINT`
- Keep each migration focused on a single logical change
- Never edit a migration already applied in any environment

## Queries
- Use CTEs (`WITH`) to decompose complex logic into named steps
- Use window functions for rankings, running totals, time-series comparisons
- Prefer explicit `JOIN` over implicit cross-joins; always alias tables
- Use `EXISTS` over `IN` for correlated subqueries against large sets
- Avoid `SELECT *` in application queries

## Indexes
- B-tree for equality and range queries on scalar types
- GIN for full-text search, JSONB containment, array operators
- GiST for geometric/spatial data and range types
- Partial indexes (`WHERE condition`) to index only relevant rows
- Covering indexes (`INCLUDE (col)`) for index-only scans
- Create all indexes `CONCURRENTLY` in production
- Verify with `EXPLAIN (ANALYZE, BUFFERS)` on realistic data

## Performance
- Run `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)` before and after query changes
- Look for Seq Scans on large tables, high-cost nested loops, unexpected Sort nodes
- Understand connection pooling: PgBouncer (transaction mode for APIs)
- Monitor table bloat; ensure `autovacuum` is healthy
- Cache hot read queries at the application layer (Redis)

## Extensions
- `uuid-ossp` / `pgcrypto` -- UUID generation
- `pg_trgm` -- trigram similarity for fuzzy text search
- `PostGIS` -- geospatial data types and indexing
- `btree_gin` / `btree_gist` -- multi-column indexes
- `pg_stat_statements` -- query execution statistics
- Enable extensions in dedicated migrations with `CREATE EXTENSION IF NOT EXISTS`
