# Arch Maintenance Center

A read-only Arch Linux health dashboard for the Noctalia v5 bar.

![Arch Maintenance Center panel](thumbnail.webp)

## What it checks

- pending repository updates and the age of the last full system upgrade;
- failed system and user services;
- root filesystem usage.

The bar widget opens a native Noctalia panel with the current diagnosis. The
panel can copy a redacted summary and read-only inspection commands. It never
runs updates, cleanup, repairs, or privileged commands.

## Requirements

- Noctalia v5.0.0-beta.9 or newer with plugin API 24;
- Arch Linux with systemd;
- `pacman-contrib` for the `checkupdates` command;
- `bash`, `grep`, `tail`, and `wc` (normally supplied by the base system).

When `pacman-contrib` is missing, the rest of the diagnosis remains available
and the updates card explains the missing dependency.

Updates invokes the fixed read-only command
`bash -o pipefail -c 'checkupdates --nocolor | wc -l'` and retains only its
numeric count. It reads at most one matching `starting full system upgrade`
line from `/var/log/pacman.log`; an unavailable log still produces a ready
updates result with an unknown date. Commands have bounded timeouts and the
service has a 35-second watchdog, so a slow mirror, unavailable service, or
lost callback cannot leave the whole diagnosis refreshing indefinitely.

The Services card checks failed `systemd` units in both the system and user
scopes and marks the diagnosis as partial when the user scope cannot be read.

The panel uses Noctalia palette roles rather than fixed colors, so backgrounds,
text, accents, borders, and controls follow the active light or dark theme.

## Usage

Enable **Arch Maintenance Center** in Noctalia's plugin manager, add the
`health` widget to a bar, and click it to open the dashboard. Right-click the
widget or use the panel refresh action to check again.

Refresh externally with:

```bash
noctalia msg plugin alexmnrs/arch-maintenance-center:monitor all refresh
```

Open the dashboard with:

```bash
noctalia msg panel-toggle alexmnrs/arch-maintenance-center:dashboard
```

## Privacy and safety

The plugin reads local package, service, and disk information without `sudo`.
It stores no diagnosis on disk and excludes usernames, hostnames, network
addresses, personal paths, and raw command output from copied diagnoses.

## License

[MIT](../LICENSE)
