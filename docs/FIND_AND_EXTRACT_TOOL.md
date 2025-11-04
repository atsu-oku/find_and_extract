# find_and_extract.sh Operator Guide

This guide explains the Bash implementation of `find_and_extract.sh`, including the v3.6.x staging-to-production workflow.

## 1. Overview

- **Target:** Identify staging artefacts, convert them to PRD values, and provide a reversible process.
- **Prerequisites:** Linux environment with Bash 4 or later.
- **Artifacts:** Logs, previews, backups, and warning files are written to `/tmp/<user>/find_and_extract/` (directory mode 700).
- **v3.6.1.0 Update:** Files under `fuel/app/config/newstaging/` are never edited directly. During `transform --apply` the script can clone `newstaging/` to `newproduction/` before applying PRD substitutions.

## 2. Subcommands

| Command     | Description | Typical Output |
|-------------|-------------|----------------|
| `scan`      | Classifies files as current infra, new infra (STG/PRD), mixed, or other. | `<host>_<ts>_{current_infra,new_infra_stg,new_infra_prd,other,mixed}.log` |
| `transform` | Converts staging hostnames/IPs/tokens to PRD equivalents. Dry-run by default; `--apply` commits with backups and a rollback log. | `*_transform_preview.log` / `*_transform.log` |
| `rollback`  | Restores files from the transform log backup entries. | Summary on stdout |

### Common Flags

- `-v`, `--verbose`
- `--skip-backup-files`
- `--dry-run` / `--apply` (transform only)
- `--file <path>` (rollback only)
- `--deletelogs`

## 3. Scan Flow

1. Print headers (hostname, version, timestamp) to stdout and every log.
2. Walk the target directory with `find -print0`, skipping SELinux paths, binary/oversized files, and optional backup names.
3. Apply regex checks for each category and write matches with ±5 lines of context.
4. Report totals and log locations on stdout.

## 4. Transform Flow

### 4.1 Validation

- When the target lies under `/var`, check `/var/www/com/ipet-ins/<system>/fuel/app/config/newproduction/`.
- Missing directories or incomplete file sets raise warnings and are recorded via `record_transform_failure`.
- If `newproduction/` is missing or incomplete and `newstaging/` exists, `transform --apply` asks whether to copy staging into production before continuing.

### 4.2 Processing

1. Build the candidate list, excluding backups, binaries, protected files, and anything in `.../newstaging/`.
2. For each file, run the staging-to-PRD substitutions and store potential changes in temporary files.
3. Dry-run emits an As-Is/To-Be preview. Apply mode prompts before writing backups and committing the new content.
4. Backups are named `<file>_<timestamp>.bak` and the rollback log records the original metadata.

### 4.3 Warning Log

- Warnings and validation issues are appended to `<host>_<ts>_warnings.log` and echoed to stdout.

## 5. Rollback Flow

1. Inspect the relevant `*_transform.log`.
2. Run `./find_and_extract.sh rollback [--file <path>] <transform-log>`.
3. The script restores from the recorded backups; missing backups are reported as failures.

## 6. Output Layout

```
/tmp/<user>/find_and_extract/
  ├── <host>_<ts>_current_infra.log
  ├── <host>_<ts>_new_infra_stg.log
  ├── <host>_<ts>_new_infra_prd.log
  ├── <host>_<ts>_other.log
  ├── <host>_<ts>_mixed.log
  ├── <host>_<ts>_warnings.log
  ├── <host>_<ts>_transform_preview.log
  └── <host>_<ts>_transform.log
```

## 7. Troubleshooting

| Issue | Suggested Action |
|-------|------------------|
| Cannot create logs | Check write access and free space under `/tmp/<user>/find_and_extract/`. |
| Missing newproduction files | Review the warnings log; if staging files exist, rerun `transform --apply` and approve the copy step. |
| No differences on dry-run | The data may already be PRD-ready or the path was excluded (e.g., `newstaging/`). Verify the search root and patterns. |
| Rollback cannot find backups | Ensure the `.bak_<timestamp>` files created during `transform --apply` still exist. |

Follow the cycle `scan` → `transform --dry-run` → review → `transform --apply` (copy staging when appropriate) → `rollback` as needed.
