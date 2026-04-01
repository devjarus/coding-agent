---
name: postgres-specialist
description: PostgreSQL expertise — schema design, migrations, query optimization, indexing strategy, and extension usage for production-grade relational databases.
---

# Postgres Specialist

Relational schema design, migration engineering, query optimization, and indexing strategy.

## When to Apply

- Designing or modifying database schemas (tables, constraints, relationships)
- Writing or reviewing migrations (adding columns, indexes, constraints)
- Optimizing slow queries or reviewing query plans
- Configuring indexes for specific access patterns
- Setting up PostgreSQL extensions
- Reviewing database integration tests

## Core Expertise (rules/core-expertise.md)

- Schema: normalization by default, DB-level constraints, timestamps on every table, UUID for public IDs
- Migrations: reversible, single logical change, safe backfill sequence, `CREATE INDEX CONCURRENTLY`
- Queries: CTEs for clarity, window functions, explicit JOINs, `EXISTS` over `IN`, no `SELECT *`
- Indexes: B-tree default, GIN for JSONB/text, partial indexes, covering indexes, always CONCURRENTLY
- Performance: `EXPLAIN ANALYZE`, connection pooling (PgBouncer), autovacuum monitoring
- Extensions: `pg_trgm`, `PostGIS`, `pg_stat_statements`, enable in dedicated migrations

## Coding Patterns (rules/coding-patterns.md)

- Table definition template with `BIGSERIAL` PK, UUID public ID, timestamps, `updated_at` trigger
- Safe non-nullable column backfill: add nullable -> backfill -> add NOT NULL
- Concurrent index creation with partial index examples
- CTE-based query patterns with window functions

## Rules

1. **Follow the project's ORM/migration tool** -- match existing Prisma, Drizzle, Flyway, etc. conventions
2. **Migrations must be reversible** -- destructive changes in separate staged migrations
3. **Test with realistic data volumes** -- validate with `EXPLAIN ANALYZE` on representative data
4. **DB-level constraints are mandatory** -- application validation is UX; DB constraint is truth
5. **Use Context7 MCP for documentation lookup**
6. **No raw SQL without justification** -- prefer ORM when possible, document why when not

## Skills

- **integration-testing** -- all schema changes tested against a real database
- **security-checklist** -- connection strings from env vars, no sensitive data in logs
