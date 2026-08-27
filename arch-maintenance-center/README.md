# Arch Maintenance Center

A read-only Arch Linux health dashboard for the Noctalia v5 bar.

The current plugin version is `0.3.0`. It uses plugin API 24, stores the
diagnosis in memory, and runs as the `monitor` service with the `health` bar
widget and `dashboard` panel.

![Arch Maintenance Center panel](thumbnail.webp)

## Platform gate

Before collecting any system data, the service reads `/etc/os-release` and
requires an exact `ID=arch` value. It does not accept `ID_LIKE=arch`. On another
distribution, or when the file cannot be verified, the panel explains why the
diagnosis is unavailable and does not offer Arch maintenance commands.

The file is read asynchronously and is limited to 64 KiB. A failed or oversized
read is an explicit platform error rather than a healthy result.

## What it checks

The service runs five read-only modules. All commands run as the current user;
the plugin does not use `sudo`.

| Area | Data collected | Limits and behavior |
| --- | --- | --- |
| Updates | Official repository updates from `checkupdates --nocolor`; last full upgrade from `/var/log/pacman.log` | Retains the count and at most eight package name/version records; `checkupdates` has a 30-second timeout; a missing log leaves the date unknown |
| Services | Failed `systemd` units in system and user scopes | Retains at most 20 units per scope; each scope has a 5-second timeout; an unreadable user scope leaves system data visible but marks the result incomplete |
| Disk | Root filesystem `/` usage | Uses Noctalia disk statistics first and `df` as a fallback; the fallback has a 5-second timeout |
| Cleanup | Pacman cache size, orphan packages, and journal storage | Uses independent sources; cache excludes private `download-*` directories; retains at most eight orphan package names; each source has a 5-second timeout |
| System Logs | Current-boot journal entries at `err` priority or higher visible to the current user | Preprocesses at most 11 events per scope with `jq`, then shows at most the ten most recent merged events; sources are limited to 128 characters and messages to 240 characters |

The service has a 35-second watchdog for a complete collection. If a command,
callback, or scope does not finish in time, the affected module is marked
incomplete and the refresh is released. Late callbacks from an older
collection cannot change a newer result.

The panel exposes an overview and detail views for Updates, Services, Disk &
Cleanup, and System Logs. The bar widget opens the dashboard and reflects the
same snapshot as the panel.

## Health and recommendations

The global health state distinguishes `ok`, maintenance information, warnings,
critical conditions, and incomplete collection. Informational signals do not
raise the global severity by themselves.

Recommendations are evidence-backed:

- pending updates are informational, becoming a warning after 14 days without a
  full system upgrade;
- failed systemd units produce a warning recommendation;
- root usage produces a warning at 80% and a critical condition at 90%;
- orphan packages produce an informational review recommendation.

Recent journal errors, pacman cache size, and journal storage remain evidence or
context. They do not create a recommendation by themselves.

## Copy actions and safety

The dashboard can copy:

- a bounded diagnosis summary containing states, counts, availability, and safe
  failed-unit names;
- read-only inspection commands when the platform is supported;
- `sudo pacman -Syu` from the Updates detail after an explicit warning.

The plugin never runs updates, cleanup, repairs, or privileged commands. Raw
command output and free-form journal messages are not included in the copied
diagnosis. Copy actions are disabled for all system commands while demo data is
active.

## Settings and visual fixtures

`Refresh interval` controls automatic refreshes and supports 15, 30, or 60
minutes. Refresh can also be requested from the panel, the widget's right-click
action, or the service IPC event.

The advanced `Developer tools` setting is disabled by default. When enabled,
the panel exposes a temporary `Data source` selector with these fixtures:

`healthy`, `recommendations`, `attention`, `critical`, `incomplete`,
`all_checks_failed`, `collecting`, `platform_checking`,
`platform_unsupported`, and `platform_error`.

Fixtures use the same snapshot path as real data, are marked as synthetic, do
not run collectors, and disable system and upgrade commands. Reloading the
plugin returns the source to `Real system`.

## Requirements

- Noctalia `v5.0.0-beta.9` or newer with plugin API 24;
- Arch Linux with `ID=arch` in `/etc/os-release` and `systemd`;
- `pacman-contrib` for `checkupdates`;
- `jq` for bounded journal preprocessing;
- base-system commands used by the collectors: `bash`, `awk`, `systemctl`,
  `journalctl`, `pacman`, `du`, `env`, and `df`.

`df` is only needed when Noctalia cannot provide native disk statistics. `grep`
and `tail` are used to recover the last full-upgrade timestamp; if either is
unavailable, Updates remains usable with an unknown timestamp. When
`pacman-contrib` is missing, the other modules remain available and the Updates
card explains the missing dependency.

## Usage

Enable **Arch Maintenance Center** in Noctalia's plugin manager, add the
`health` widget to a bar, and click it to open the dashboard. Right-click the
widget or use the panel refresh action to check again.

For local development from the repository root:

```bash
noctalia msg plugins source add arch-maintenance-center-dev path "$(pwd)"
noctalia msg plugins enable alexmnrs/arch-maintenance-center
```

Refresh externally with:

```bash
noctalia msg plugin alexmnrs/arch-maintenance-center:monitor all refresh
```

Open the dashboard with:

```bash
noctalia msg panel-toggle alexmnrs/arch-maintenance-center:dashboard
```

## Testing

The repository keeps pure collection and presentation models separate from
Noctalia so they can be tested with Luau. The CI workflow compiles all Luau
files, checks literal Noctalia module paths, and runs every `tests/*_spec.luau`
file:

```bash
for file in arch-maintenance-center/*.luau arch-maintenance-center/lib/*.luau tests/*.luau; do
  luau-compile "$file" >/dev/null
done
bash scripts/check_noctalia_requires.sh
for test_file in tests/*_spec.luau; do
  luau "$test_file"
done
```

## Privacy and safety

The plugin reads local package, service, disk, and journal information without
`sudo`. It stores no diagnosis on disk. The copied diagnosis excludes raw
command output, free-form journal messages, usernames, hostnames, network
addresses, and personal paths by default; bounded summaries and safe failed-unit
names are retained for traceability.

## License

[MIT](../LICENSE)
