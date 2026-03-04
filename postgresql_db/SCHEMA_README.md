# PostgreSQL Schema: AI Team Task Manager

This document explains how to initialize, (re-)migrate, and manage the database schema for the task manager's relational data.

## Files

- `schema.sql` — This file (generated, version-controlled) contains **the full schema for users, roles, projects, tasks, columns, comments, notifications, sessions, and attachments metadata** (no test data by default except roles).
- `db_connection.txt` — Contains the canonical connection string for local development.
- `startup.sh` — Initializes the database and user/role permissions based on environment/defaults.
- See `backup_db.sh` and `restore_db.sh` for dump/restore helpers.

## Quickstart: Creating Schema

1. Ensure the database is running (`startup.sh` will set up DB and user).
2. Get connection info from `db_connection.txt` (e.g.):
   ```
   psql postgresql://appuser:dbuser123@localhost:5000/myapp
   ```
3. Initialize (or update) schema from this folder:
   ```
   psql postgresql://appuser:dbuser123@localhost:5000/myapp -f schema.sql
   ```
   Or interactively:
   ```
   psql -U appuser -h localhost -d myapp -p 5000
   -- then run the contents of schema.sql
   ```
4. Schema supports idempotent creation (all tables use `IF NOT EXISTS`; inserts use `ON CONFLICT` for built-in roles).

## Migration/Updates

- To update schema, edit `schema.sql` and reapply as above.
- For destructive migrations or field refactor, backup first:
  ```
  ./backup_db.sh
  ```

## Environment Variables

- `POSTGRES_URL, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB, POSTGRES_PORT` (as configured by startup scripts and in `db_visualizer/postgres.env`).

## Best Practices

- NEVER store actual attachment files in the DB: Only store metadata and file URLs.
- Each app instance/user must have a unique UUID (`gen_random_uuid()`). For cloud or test environments, prefer UUID over SERIAL for user and business-entity IDs.
- Roles can be extended but `admin` and `member` are reserved/app-default.
- Use foreign key constraints with `ON DELETE SET NULL` for user-grained objects, `ON DELETE CASCADE` for deep child records (like tasks/comments belonging to deleted projects/tasks).

## Development & CI

- To reset DB: restore from backup or drop all tables/DB and rerun `schema.sql`.
- The schema is versioned: update this README + schema.sql for any changes. 
- If a new table or constraint is added, revisit all cross-service uses (backend queries, migrations, etc).

## Additional Notes

- Add more roles as needed by inserting into `roles`.
- For advanced GitOps/CICD or local environments: run all migrations atomically using standard PostgreSQL tooling.
- Columns in Kanban are per-project. Tasks are positioned in columns with `order_in_column`.
- Sessions support JWT with refresh token hashes and audit fields for device/IP.

---

For any issues with initialization, check:
- Database is running and accepting connections
- User/password permissions as per `startup.sh`
- That `pgcrypto` extension (for UUID) is installed (`CREATE EXTENSION IF NOT EXISTS pgcrypto;`) — add this at the top of schema if using bare PostgreSQL.

---
