# find_and_extract.sh Version History

## v3.6.3.0 – 2025-11-05

- `/etc/profile` transform now always converts staging tokens to production equivalents and appends constant proxy exports pointing to `http://172.16.162.6:3128/`.
- `.save` files and filenames containing an eight-digit date stamp are excluded from processing.
- Treasure Data repo generation now selects OS-specific URLs (CentOS6, RHEL7, RHEL9) and stores the new GPG key location after performing a connectivity check.

## v3.6.1.0 — 2025-11-04

- Treat `fuel/app/config/newstaging/` as the canonical staging snapshot. Transformation now skips those files entirely and, during `transform --apply`, asks whether the directory should be copied over `newproduction/` before any PRD substitutions run.
- Added uniform warning/ failure recording via `record_transform_failure`, and tightened the validation flow so missing files are reported once and written to the warnings log.
- Bumped the default verbose messages and documentation to reflect the new behaviour.

## v3.6.0.0 — 2025-11-04

- Added validation of `newproduction/` and `newstaging/` beneath `/var/www/com/ipet-ins/<system>/fuel/app/config/`, surfaced warnings, and introduced warning log emission.

## v3.5.1.0 — 2025-10-30

- Reclassified staging/production markers found in log paths and refreshed the execution summary strings.

## v3.5.0.0 — 2025-10-30

- Normalised backup file names to `*_YYYYMMDD_HHMM.bak`, expanded mixed-definition logging, and broadened the backup-file detection heuristics.

## Earlier Releases

- 3.4.x: Iterative improvements to hostname/IP pattern coverage, comment filtering, and staging keyword handling.
- 3.3.0.0: Introduced the `transform` subcommand with dry-run defaults, confirmation prompts, and automatic backups.
- 3.2.x: Expanded current-infra detection (IP/hostname patterns) and refined AWS exclusion logic.
- 3.1.x: Added detailed comments, localisation tweaks, and initial rollback scaffolding.
- 3.0.x and below: Initial public releases and miscellaneous formatting fixes.
