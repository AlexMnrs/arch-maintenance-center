# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project will follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
when it begins publishing releases.

The plugin and catalog currently declare version `0.3.0`. Until a release is
published, changes remain under `Unreleased`.

## Unreleased

### Added

- A compact, navigable list of recommended actions for updates, failed units,
  low space on `/`, and orphan packages.
- A preflight check of `/etc/os-release` that limits diagnosis to Arch Linux
  confirmed through `ID=arch`.
- Navigable detail views for Updates, Services, Disk & Cleanup, and System Logs
  without changing the panel size or API.
- Bounded samples of pending official packages and failed units, with
  indicators when more items exist than are shown.
- Pacman cache, orphan-package, and journal-storage information.
- Recent visible journal error events, bounded per scope and presented as
  informational evidence.
- A dedicated button for copying the upgrade command, with an explicit warning
  that it changes the system and is not executed by the plugin.
- Tests for byte formatting, cleanup, logs, truncation, and diagnosis
  redaction.
- The initial project vision, scope, and safety principles.
- A public README and first-version visual reference.
- Local instructions for development agents.
- A functional Noctalia v5 plugin with a health widget, panel, and monitoring
  service.
- Checks for updates, failed units, and root-disk usage.
- A redacted diagnosis and copyable inspection commands.
- Periodic refresh configuration, refresh IPC, and automated Luau tests.
- Optional developer tools with ten visual fixtures for reviewing healthy,
  recommendation, warning, error, loading, and incompatible-platform states
  without touching the system.
- An MIT license and GitHub continuous-integration workflow.

### Changed

- Public and project documentation is synchronized with the `0.3.0`
  implementation contract: modules, collection limits, states,
  recommendations, settings, fixtures, commands, refresh behavior, and CI
  validation.
- Recommended maintenance is calculated from concrete actions instead of all
  informational modules; journal errors no longer raise the maintenance summary
  by themselves.
- The copyable diagnosis includes the platform and recommended actions, and no
  longer offers Arch commands on an incompatible platform.
- The global summary distinguishes available maintenance from warnings and
  critical conditions; an update count does not become an alert by itself.
- Snapshots distinguish real data from demo fixtures; the temporary selector
  resets to `Real system` when the plugin reloads and keeps the panel and widget
  synchronized.
- Updates shows an absolute date and time for the last full upgrade and for the
  availability check instead of only elapsed days.
- The copyable diagnosis includes Cleanup and Logs counts and availability
  without including free-form journal messages.
- The panel explains which module prevents a complete diagnosis, distinguishes
  the first load from an incomplete result, and clarifies the `systemd` scopes
  checked by Services.
- Panel controls and colors follow Noctalia's native palette roles and
  proportions for the active theme; the last-diagnosis time also follows the
  user's configured format.

### Fixed

- Logs preprocesses one bounded JSON sample per scope before the callback,
  avoiding Luau callback CPU-budget overruns while decoding events.
- Cache measurement omits private `download-*` directories created by pacman,
  which previously made `du` fail despite producing a valid size.
- The maintenance state no longer uses color roles unknown to Noctalia API 24.
- Available log scopes no longer retain stale error details in shared state.
- The header prioritizes an incomplete diagnosis over informational maintenance,
  and Disk & Cleanup keeps unavailable cleanup sources visible.
- Log collection normalizes messages locally instead of relying on an optional
  `journalctl` option, improving compatibility.
- Updates, Services, and orphan-package collection limits the volume delivered
  to Noctalia callbacks.
- Updates reduces processed output to one count and one `pacman.log` line to
  respect the Noctalia callback CPU budget.
- A 35-second watchdog terminates stuck collections, publishes an incomplete
  diagnosis, and re-enables Refresh; late callbacks cannot change a later
  collection.
- Failure to check user units is no longer presented as a complete diagnosis.
- Entrypoints use literal `require` paths compatible with Noctalia API 24,
  without fallbacks that hide errors; the widget no longer depends on the demo
  fixture build chain.
- The pattern that parses `checkupdates` output no longer contains an invalid
  escape for the Luau parser.

### Security

- Fixtures do not run collectors or enable inspection or upgrade commands; the
  synthetic diagnosis is explicitly identified as demo data before it is copied.
