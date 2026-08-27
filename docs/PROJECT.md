# Project foundations

This document records the scope, implemented behavior, and product decisions
for Arch Maintenance Center. The public documentation summarizes this contract;
this file keeps the detail needed to develop the project without expanding its
scope by accident.

## Current status

Version `0.3.0` of the `alexmnrs/arch-maintenance-center` plugin implements a
service + widget + panel architecture for Noctalia v5 with plugin API 24. The
first functional version is read-only and covers updates, failed services, disk
usage, cleanup information, and recent journal errors. The initial interface is
English through Noctalia Translate.

## Vision

Create an Arch Linux maintenance center integrated with Noctalia that condenses
system status into a quick, actionable read. It should be useful for daily use
and for learning what is actually happening on the machine, without hiding
evidence or automating risky actions.

## Initial user and context

The originating use case is an Arch Linux user interested in system
administration who wants to observe and maintain a laptop from the desktop
environment. The product must not be coupled to a particular hardware model.

## Goals and scope for version 0.3.0

1. Summarize system health with understandable severity and causes.
2. Bring updates, services, logs, and storage into one view.
3. Order signals by urgency and usefulness, not by their technical source.
4. Allow users to copy a reproducible diagnosis and inspection commands.
5. Provide enough context for users to make an informed decision.

Networking is a future possibility, not a capability of this version.

## Current non-goals

- Automatically run updates, cleanup, or repairs.
- Request or retain administrator credentials.
- Replace `pacman`, `systemctl`, `journalctl`, or other system tools.
- Promise support for other distributions before Arch Linux is validated.
- Accept Arch derivatives solely because they declare `ID_LIKE=arch`.
- Query the AUR, calculate download sizes, or estimate recoverable space.
- Turn generic warnings or journal events into incidents without an explicit
  rule.
- Add networking, predictive diagnosis, or continuous monitoring.
- Interpret logs generatively without an explicit privacy and quality policy.

## Fundamental rules

### Safety before convenience

- Observation is read-only wherever possible.
- No ambiguous button may make changes to the system.
- Suggested commands are shown in full before the user copies or runs them
  independently.
- Each potentially destructive action must explain its scope, risk, and
  reversibility.
- Collection failures degrade the affected module; they are never presented as
  a healthy system by default.

### Evidence before conclusions

- A global state must be traceable to concrete signals.
- Error, warning, information, and unavailable data are distinct states.
- The number of updates alone is not treated as an emergency.
- Log summaries retain the time, source, and access path to the original event.
- The copyable diagnosis avoids secrets and personal data by default.

### Interface and experience

- Critical information should be understandable within seconds.
- Color reinforces meaning but is never the only indicator.
- Modules share loading, empty, error, and unavailable states.
- The compact view answers “what should I look at?”; the detail view answers
  “why?”.
- The design follows Noctalia's visual and interaction conventions.

## Product areas

| Area | Status | Signals and outcome |
| --- | --- | --- |
| Global state | Implemented | Aggregated severity, completeness, and prioritized causes |
| Updates | Implemented | Official repository updates, package sample, and last full upgrade |
| Services | Implemented | Failed system and user `systemd` units with detail access |
| Disk & Cleanup | Implemented | `/` usage, pacman cache, orphan packages, and journal storage |
| System Logs | Implemented | Current-boot `err`-or-higher events readable by the current user |
| Networking | Future | Connectivity, DNS, and latency; sources and minimum permissions are still undefined |

## Closed technical decisions

- **Platform:** Arch Linux with `systemd` on Noctalia v5.
- **Minimum compatibility:** Noctalia `v5.0.0-beta.9`, plugin API 24.
- **Platform check:** the service reads `/etc/os-release` asynchronously, with a
  64 KiB maximum, and collects data only when it finds a valid `ID=arch`. It
  does not use `ID_LIKE` as a substitute. An incompatible or unverifiable
  platform runs no collectors and offers no Arch commands.
- **Language:** Luau, with pure modules testable outside Noctalia.
- **Architecture:** collection service, in-memory shared state, bar widget, and
  declarative panel.
- **Distribution:** source repository with `catalog.toml` and an installable
  plugin in its own subdirectory.
- **License:** MIT.
- **Initial interface language:** English through Noctalia Translate.
- **Structural reference:** AlexMnrs's GitHub Activity plugin.
- **Privacy:** the diagnosis is not stored on disk; the copyable diagnosis
  excludes raw stdout and free-form journal messages, and retains only bounded
  values, states, counts, availability, and validated unit names.
- **Demo tools:** an advanced setting disabled by default, a temporary fixture
  selector inside the panel, and a return to `Real system` when the plugin
  reloads. Synthetic snapshots are marked as `source.kind=fixture`, feed the
  widget and panel through the same path as real data, run no collectors, and
  do not enable copyable commands.

## Implemented collection

All checks are read-only, run as the current user, and have bounded timeouts.
Noctalia limits each command callback to 25 ms of CPU time, so callbacks receive
and analyze only small, bounded data. A timeout, lost callback, or unavailable
scope leaves the affected module incomplete; it does not become a healthy
result.

| Module | Source | Scope and limit |
| --- | --- | --- |
| Updates | `checkupdates --nocolor` summarized by a fixed pipeline and the last relevant line from `/var/log/pacman.log` | Official repositories, no `sudo`; retains the total and at most eight package name/version records; 30 s for `checkupdates`; if `grep` or `tail` is missing, the date is unknown |
| Services | `systemctl --failed` and `systemctl --user --failed`, summarized by a fixed pipeline | Failed system and user units; retains at most twenty per scope; 5 s per scope; if the user scope fails, system data is retained and the module is incomplete |
| Disk | Native Noctalia statistics, with `df` as a fallback | Root filesystem `/`; the fallback has a 5 s timeout |
| Cleanup | `du --summarize --block-size=1 --exclude='download-*' /var/cache/pacman/pkg`, `pacman -Qtdq`, and `journalctl --disk-usage` | Cache excludes private temporary-download directories; orphan packages have a maximum sample of eight; sources are independent, 5 s per source |
| Logs | `journalctl` and `journalctl --user` from the current boot at `err` priority or higher, summarized by a fixed `jq` expression | At most eleven events per scope and ten shown after merging; the data delivered to Luau contains only a timestamp, priority, a 128-character source, and a 240-character message |

If `pacman-contrib` is absent, Updates is unavailable but the other modules are
not hidden. If `jq` is absent, Logs is an error. Cleanup sources are preserved
independently, so an inaccessible source is marked without hiding the others.
The user scope of Services and Logs can also be incomplete while the system
result remains visible.

Services does not check that every unit is active and does not attempt to repair
or restart services: it reports only units that `systemd` already considers
failed.

Cleanup keeps the cache, orphan, and journal results separate. Orphans are an
informational maintenance signal; cache and journal size are exposed as context
until configurable and documented thresholds exist.

Logs collects only error-priority or higher events that the current user can
read. Normalized evidence is shown in the panel, but free-form messages are not
copied into the diagnosis: the diagnosis contains only counts, truncation, and
scope availability.

## State interpretation

Global state distinguishes the severity of maintenance data: an `info` signal
does not by itself create a global attention recommendation, while only
`warning` and `critical` raise severity. Recommendations derive from concrete
signals:

- pending updates: an `info` recommendation that becomes `warning` after 14
  days since the last full upgrade;
- failed units: a `warning` recommendation;
- root disk usage above 80%: a `warning` recommendation, and `critical` from
  90%;
- orphan packages: an `info` recommendation.

Recent journal errors, cache size, and journal size remain evidence or context.
Modules with errors, unavailable data, or an incomplete scope are reported in
the summary alongside the known severity.

Updates details include `sudo pacman -Syu` only as copyable text with a warning;
it is not included in the general inspection commands and is never run by the
plugin. General commands are offered only on a supported Arch platform, and
unit names are validated before interpolation.

## Lifecycle and refresh

- When the plugin is enabled, the service checks the platform first and starts
  the five modules only afterward.
- The panel and the widget context menu request a refresh through shared state;
  the service also accepts the `refresh` IPC event.
- The `refresh_interval_minutes` setting supports 15, 30, or 60 minutes. A
  one-second internal tick watches the watchdog and schedules the next refresh
  without turning every tick into a collection.
- Only one valid collection stays active. Concurrent requests are queued for
  another run after the current one completes.
- Each collection has a generation and a defensive 35-second deadline. When it
  expires, pending modules receive `collection_deadline`, an incomplete
  diagnosis is published, and refresh is released; duplicate or late callbacks
  from an earlier generation are ignored.
- The Refresh button is disabled only while that valid collection is active.
- With a fixture selected, Refresh rebuilds synthetic data and does not run real
  collectors. Disabling Developer tools or reloading the plugin returns the
  source to `Real system`.

## Development fixtures

The temporary selector exposes ten ids for reviewing states without touching the
system:

`healthy`, `recommendations`, `attention`, `critical`, `incomplete`,
`all_checks_failed`, `collecting`, `platform_checking`,
`platform_unsupported`, and `platform_error`.

The fixtures cover a healthy state, informational recommendations, attention, a
critical condition, partial failures, total failure, loading, and the three
platform-check outcomes. Inspection and upgrade commands are disabled while a
fixture is active.

## Validation and CI

Collection, classification, recommendation, diagnosis, fixture, and refresh
models are tested outside Noctalia with Luau. CI:

1. installs Luau in an Arch container;
2. compiles all entrypoints, modules, and tests;
3. verifies that Noctalia module `require` calls are literal and compatible with
   API 24;
4. runs every `tests/*_spec.luau` file.

## Future decisions

Before expanding the first version, the project must investigate and record:

- the evolution of the global-state formula and configurable thresholds;
- support for AUR helper managers;
- interpretation of generic warnings before treating them as incidents;
- data sources and minimum network permissions;
- real download sizes and any corrective action.

Firm decisions must be added to this document with their rationale. User-visible
changes must also be added to the changelog.
