# find_and_extract.sh Shell Variant Spec

The Bash build of `find_and_extract.sh` is the lightweight companion to the migration tooling used by the team. This note summarises how the script is shipped, how it should be executed, and the safety guarantees introduced in v3.6.x.

## Delivery and Execution

- Copy `repo/find_and_extract.sh` onto the target VM and run it locally (Bash 4 or later).
- Logs and temporary files are written to `/tmp/<user>/find_and_extract/` with directory mode 700.
- The CLI exposes `scan`, `transform`, and `rollback` subcommands from a single entry point.

## Subcommands at a Glance

| Command | Purpose |
|---------|---------|
| `scan` | Read-only classification of staging vs. production artefacts; writes category logs for review. |
| `transform` | Converts staging artefacts to production equivalents. Default is preview; `--apply` prompts, writes backups, and records a rollback log. |
| `rollback` | Restores files listed in a transform log (optionally narrowed via `--file`). |

### Shared Options

- `-v/--verbose`
- `--skip-backup-files`
- `--dry-run` / `--apply` (transform only)
- `--file <path>` (rollback only)
- `--deletelogs`

## Safety Nets

- `/etc/nginx/nginx.conf` and `/etc/httpd/httpd.conf` are always skipped.
- When targeting `/var`, the script validates `/var/www/com/ipet-ins/<system>/fuel/app/config/newproduction/`. Missing directories or files raise warnings and are written to the warnings log.
- v3.6.1.0 treats `fuel/app/config/newstaging/` as canonical staging data: it is never edited directly. In `transform --apply` the user may approve copying `newstaging/` to `newproduction/` before PRD substitutions run.
- Each applied change creates a `*.bak_<timestamp>` backup next to the original and appends an entry to the transform log, enabling reliable rollback.

## Rollback Quick Steps

1. Locate the relevant `<host>_<timestamp>_transform.log` under `/tmp/<user>/find_and_extract/`.
2. Run `./find_and_extract.sh rollback [--file <path>] <transform-log>`.
3. Review the summary; missing backups are reported as failures.

Refer to `docs/FIND_AND_EXTRACT_TOOL.md` for day-to-day operational guidance.
