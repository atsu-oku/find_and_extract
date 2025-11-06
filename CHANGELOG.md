# find_and_extract.sh Version History

## v3.6.4.0 - 2025-11-06

- After applying td-agent repository updates, rewrite `CentOS-*` repo definitions to use `https://vault.centos.org`, pin `$releasever` to the detected major version, force `x86_64`, and convert all `.repo` files to `https://`.
- Automatically disable `remi-safe`, `remi-php*`, `zabbix`, and `zabbix-non-supported` via `yum-config-manager`/`dnf config-manager`, then run `yum install td-agent --disablerepo=* --enablerepo=treasuredata` with logs stored under `/tmp/<user>/find_and_extract`.

## v3.6.3.0 - 2025-11-05

- Switch td-agent repository provisioning to `packages.treasuredata.com`, selecting `/3/redhat/6/` for RHEL/CentOS 6 and `/4/redhat/{7,8,9}/` for newer releases, and fetch the GPG key from `https://packages.treasuredata.com/GPG-KEY-td-agent`.
- Source `/etc/profile` before probing the repository and emit actionable guidance when a 403 indicates a missing firewall whitelist entry.
- Harden localised printf helpers against option-looking message strings.

## v3.6.2.0 - 2025-11-05

- Append proxy exports to `/etc/profile` during transform when missing, using environment values or the default `http://172.16.162.6:3128/`.
- Updated documentation to describe proxy fallback behaviour.

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
