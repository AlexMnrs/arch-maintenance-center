# Arch Maintenance Center

A read-only health and maintenance panel for Arch Linux, implemented as a
[Noctalia](https://docs.noctalia.dev/) plugin.

Arch Maintenance Center answers two questions in a few seconds: **is the
system healthy?** and **what should I review now?** It brings scattered Arch
signals into a compact view, explains their priority, and suggests the next
step without taking control of the machine.

![Arch Maintenance Center panel](./arch-maintenance-center/thumbnail.webp)

> [!NOTE]
> The interface starts from this [conceptual style frame](./style-frame-v1.png),
> which is kept as a reference and must not be mistaken for a functional
> screenshot.

## Current status

Version `0.3.0` of the `alexmnrs/arch-maintenance-center` plugin requires
Noctalia v5 with plugin API 24 and runs five read-only checks after confirming
that `/etc/os-release` contains `ID=arch`:

- **Updates:** official repository updates, the pending total, at most eight
  package name/version pairs, and the last full-upgrade date from
  `/var/log/pacman.log` when available;
- **Services:** failed `systemd` units in the system and user scopes, with at
  most twenty units per scope;
- **Disk:** usage of the root filesystem `/`;
- **Cleanup:** pacman cache, orphan packages, and journal storage;
- **System Logs:** recent journal errors visible to the current user from the
  current boot, with a bounded and normalized sample.

The global state distinguishes a healthy system, recommended maintenance,
attention, a critical condition, and incomplete collection, with actions linked
to concrete evidence.

The panel provides detail views, initial, manual, and scheduled refreshes, a
check timestamp separate from the last full-upgrade date, a redacted copyable
diagnosis, and read-only inspection commands. The bar widget opens the panel
and reflects the current state.

Platform checks, user units, Cleanup sources, and logs explicitly distinguish
incomplete results from errors and from a healthy system. Each collection has a
35-second watchdog; a late callback cannot modify a later collection.

It does not include AUR, download sizes, classification of generic warnings or
logs as incidents, recoverable-space calculations, networking, or continuous
monitoring metrics. It also does not run updates, cleanup, repairs, or
privileged commands.

## Recommendations and safety

Recommendations come from concrete signals:

- pending updates are informational and become a warning after at least 14 days
  since the last full upgrade;
- a failed unit produces a review recommendation;
- root usage produces a warning at 80% and a critical state at 90%;
- orphan packages produce an informational recommendation.

Journal errors, cache size, and journal size remain evidence or context and do
not raise the global state by themselves. The copyable diagnosis contains
states, counts, availability, and safe unit names; it does not include free-form
journal messages or raw stdout.

The plugin is **informational and non-destructive**. It does not request or
store administrator credentials. The Updates detail can copy the command
`sudo pacman -Syu` after explaining that it changes packages and may request a
password, but the command is never run from Noctalia. General copied commands
are for inspection only and are offered only on a supported platform.

## Configuration and visual development

The `Refresh interval` setting supports automatic refreshes every 15, 30, or 60
minutes. `Developer tools` is an advanced setting disabled by default; enabling
it adds the temporary `Data source` selector to the panel with these ten
fixtures:

`healthy`, `recommendations`, `attention`, `critical`, `incomplete`,
`all_checks_failed`, `collecting`, `platform_checking`,
`platform_unsupported`, and `platform_error`.

Fixtures use the same data path as the widget and panel, do not run collectors
or enable system and upgrade commands, and are marked as demo data. The plugin
returns to `Real system` when it reloads.

## Local development

To test a local copy from the repository root:

```bash
noctalia msg plugins source add arch-maintenance-center-dev path "$(pwd)"
noctalia msg plugins enable alexmnrs/arch-maintenance-center
```

The widget is named `health`, the panel is `dashboard`, and the collection
service is `monitor`. The service can also be refreshed or the panel opened via
IPC:

```bash
noctalia msg plugin alexmnrs/arch-maintenance-center:monitor all refresh
noctalia msg panel-toggle alexmnrs/arch-maintenance-center:dashboard
```

The pure tests and the checks used by CI run with:

```bash
for file in arch-maintenance-center/*.luau arch-maintenance-center/lib/*.luau tests/*.luau; do
  luau-compile "$file" >/dev/null
done
bash scripts/check_noctalia_requires.sh
for test_file in tests/*_spec.luau; do
  luau "$test_file"
done
```

## Requirements and project state

- Arch Linux with `ID=arch` in `/etc/os-release` and `systemd`;
- Noctalia v5.0.0-beta.9 or later with plugin API 24;
- `pacman-contrib` for `checkupdates` and `jq` for bounded log preprocessing;
- Arch base-system commands (`bash`, `awk`, `systemctl`, `journalctl`, `pacman`,
  `du`, `env`, and `df`) for the corresponding sources. `grep` and `tail` are
  only needed to recover the last full-upgrade date; if they are missing, the
  Updates card remains available with an unknown date.

The plugin uses Luau and a service, widget, and panel architecture inspired by
[GitHub Activity](https://github.com/AlexMnrs/github-activity). The pacman
cache excludes private `download-*` directories. Log events are limited to
those readable by the current user, and collection keeps the diagnosis only in
memory. The scope, product rules, and pending decisions are in
[`docs/PROJECT.md`](./docs/PROJECT.md). Notable changes are recorded in
[`CHANGELOG.md`](./CHANGELOG.md).

## License

[MIT](./LICENSE)
