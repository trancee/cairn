# Upgrading from a pre-courier build crashes on `no such table: courier`

Type: bug
Status: done
Blocked by: none

## Question

PR #82 (`cea4a64`) added `CREATE TABLE courier` to
`sdk/src/commonMain/sqldelight/ch/trancee/cairn/sdk/db/Rows.sq` without a
SQLDelight migration (`.sqm`). A database created by an earlier build keeps
schema version 1 and has no `courier` table. The app then crashes at start:

```
android.database.sqlite.SQLiteException: no such table: courier (code 1 SQLITE_ERROR):
, while compiling: SELECT slot, version, ciphertext FROM courier
```

Seen 2026-10-28 on the P30 lite (`L2N0220117013464`) and on several fleet
phones (e.g. Pixel 4a `192.168.50.244:5555`) after `adb install -r`.
`pm clear` works around it.

Fix: add `1.sqm` with the `courier` table, enable `verifyMigrations`, and add a
test that opens a version-1 database and reads courier rows. Decide whether
pre-release databases need migrations at all (Constitution Q7). If not,
record that and reset the stores instead of crashing.

## Resolution

Two causes, both fixed:

1. **Schema.** `migrations/1.sqm` creates the `courier` table, so a version-1
   database migrates to version 2. `migrations/1.db` holds the version-1
   schema, and `verifyMigrations = true` makes `:sdk:check` fail when a
   schema change lacks its migration.
2. **Blobs.** An old database also holds version-2 blobs, which the core
   rejects with `InvalidBlob` (ADR 0036 §1). `LinkDriver` now wipes the rows
   (`Rows.wipe()`), reports `STORAGE_RESET` and restores an empty core, as
   for unreadable rows (ADR 0035 §5). Before, it crashed.

Tests: `SealedRowStoreTest.aVersionOneDatabaseMigratesToHoldCourierRows`,
`wipeDeletesEveryRow` (SQLite, in-memory and iOS `RowStorageTests`), and
`LinkDriverTest.rowsTheCoreCannotRestoreAreWipedAndReportedAsAStorageReset`.
