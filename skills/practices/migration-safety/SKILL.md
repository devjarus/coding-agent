---
name: migration-safety
description: Zero-downtime database migration patterns — safe column additions, index creation, data backfills, and rollback strategies. Use when writing or reviewing database migrations for production systems.
---

## When to Apply
- Writing database migrations (any ORM/tool)
- Reviewing migration files
- Data lead reviewing Postgres specialist output
- Planning schema changes for a live system

## Priority Rules

### CRITICAL
- MIG-01: Never drop a column/table in the same deploy that removes the code using it. Deploy code change first (stop reading it), then drop in next deploy.
- MIG-02: Add columns as NULLABLE first, backfill data, then add NOT NULL constraint in a separate migration. Never add NOT NULL column without a default to a table with existing data.
- MIG-03: Every migration must have a rollback (down migration). Test the rollback works.

### HIGH
- MIG-04: CREATE INDEX CONCURRENTLY — never create indexes on large tables without CONCURRENTLY (blocks writes in Postgres otherwise)
- MIG-05: Rename in 3 steps: add new column → backfill → update code to use new → drop old. Never rename a column in one migration.
- MIG-06: Test migrations against production-size data. A migration that runs in 1ms on 100 rows may lock the table for 10 minutes on 10M rows.

### MEDIUM
- MIG-07: Backfills should be batched (1000-10000 rows at a time) with sleep between batches to avoid overwhelming the database
- MIG-08: Set statement_timeout on long migrations to prevent runaway locks
- MIG-09: Deploy migrations BEFORE new code (new code must work with both old and new schema during rollout)

## Safe Change Patterns

| What you want to do | How to do it safely |
|---|---|
| Add nullable column | Single migration, safe |
| Add NOT NULL column | Add nullable → backfill → add constraint |
| Rename column | Add new → copy data → update code → drop old |
| Drop column | Stop reading in code → deploy → drop column |
| Add index | CREATE INDEX CONCURRENTLY |
| Change column type | Add new column with new type → migrate data → swap code → drop old |
| Add enum value | ALTER TYPE ADD VALUE (safe in Postgres) |
| Remove enum value | Never (create new enum type instead) |
