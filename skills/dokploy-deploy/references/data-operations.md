# Data operations

Always back up before writing to an environment's database. Keep each step
verifiable by counts on both sides.

## Backup and restore

Find the DB container by its suffixed App Name and dump inside it (no exposed port, no password on the command line):

```bash
c=$(docker ps --filter name=<db-appname> --format '{{.Names}}' | head -1)
f=/root/backups/<project>-<env>-$(date -u +%Y%m%dT%H%M%SZ)-<reason>.dump
mkdir -p /root/backups && docker exec "$c" pg_dump -U <user> -d <db> -Fc > "$f" && ls -la "$f"
```

Download a local copy (`tailscale ssh root@<host> "cat $f" > <local-path>`) into a gitignored folder and compare byte sizes. Restore, only with explicit approval:
`docker exec -i "$c" pg_restore --clean -U <user> -d <db> < "$f"`.

Dokploy's scheduled backups need an S3 destination and a backup entry on the database; recommend setting them up before the next release when none exist.

## Copy rows into another environment

Prefer the application's own import flows when they exist and are practical. For a direct copy:

1. Inventory both sides: row counts per table, owners, foreign keys (`pg_constraint`), and which columns hold user or profile IDs. Check whether JSON columns embed IDs that would need remapping.
2. Decide scope with the user: which owners' data, which statuses (skip soft-deleted rows and in-flight job states), and what to do with dependencies owned by someone else (for example a shared system library).
3. Never copy environment-bound data: accounts and sessions, JWT signing keys (often encrypted with the environment's secret), OAuth/MCP clients and tokens, third-party tokens encrypted with an environment key, payment projections, job queue rows, idempotency receipts.
4. Generate one SQL file on the source: temp tables (`CREATE TEMP TABLE m_x (LIKE x) ON COMMIT DROP`), `COPY m_x (...) FROM stdin` blocks produced by `COPY (select ...) TO STDOUT`, a mapping table from source owner IDs to target IDs looked up by email, guard `DO` blocks that raise when a target account or profile is missing, then `INSERT ... SELECT` with remapped columns and `ON CONFLICT DO NOTHING` in foreign-key order. Insert self-referencing parents as `NULL` first and `UPDATE` them afterwards.
5. Apply on the target in one transaction: `docker exec -i "$c" psql -U <user> -d <db> -v ON_ERROR_STOP=1 --single-transaction < file.sql`. Print staged counts from the temp tables and verify target counts per owner.
6. Plain `pg_dump --data-only --table=... --column-inserts --on-conflict-do-nothing` is enough when rows need no remapping.

Script generation through `docker compose exec` is easier in a bash script file than inline in zsh, which does not word-split command strings held in variables.

## Copy object-storage files

Copy only the keys the copied rows reference (extract them with SQL from the rows or JSON), keeping the same keys so the app resolves them unchanged. Check how the app maps logical buckets to keys first (some prefix a logical bucket name inside one physical bucket).

```bash
# source (for example local MinIO) → temp dir, parallel
cat keys.txt | xargs -P 16 -I{} aws --endpoint-url <src> s3 cp --only-show-errors "s3://<src-bucket>/{}" "<tmp>/{}"
# temp dir → target (for example R2), credentials from a mode-600 temp env file, deleted afterwards
aws --endpoint-url https://<account>.r2.cloudflarestorage.com s3 sync --only-show-errors "<tmp>/<prefix>/" "s3://<bucket>/<prefix>/"
```

Load target credentials from the service spec into a temp file with `umask 077`, source it, delete it, and never echo it. Verify object counts on the target, then delete the temp directory. Stop any local services you started for the copy.

## Create an operator/admin account

When the auth library ships a CLI, check that it actually runs inside the app's image before documenting it: CLIs that load the app config twice, or `bun run <name>` resolving to a same-named file instead of the binary, fail silently. A reliable fallback is a one-off container (see `swarm-diagnostics.md`) running a short script against the app's own auth context that creates the user, marks the email verified, sets the role and stores a hashed password read with echo off. Dry-run it read-only first (load the context, check the email does not exist). Never place the password in flags, shell history or chat.
