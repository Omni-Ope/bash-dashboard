# Linux System Dashboard

A single bash script that prints the health of a Fedora or Ubuntu Server machine in one view. It covers system info, CPU and memory, disks, processes, network, services, logins, and recent journal errors.

The script is `dashboard.sh`. Thresholds live in `dashboard.conf`. The class slides are `Bash-Dashboard-Presentation.pptx`.

## Setup

Copy this folder to each VM, then make the script executable:

```bash
chmod +x dashboard.sh
./dashboard.sh
```

Run it with bash. `sh dashboard.sh` will fail because the script uses bash features.

Ways to get the files onto the Week 0 VMs:

- `scp -r bash-dashboard user@vm-ip:~/`
- A VMware shared folder
- Clone the git repo from a host the VM can reach

`dashboard.conf` is optional. If it is missing, the script uses the built-in thresholds.

## Usage

```bash
./dashboard.sh
./dashboard.sh --watch
./dashboard.sh --log "$HOME/dashboard.log"
./dashboard.sh --config ./dashboard.conf
./dashboard.sh --no-color
./dashboard.sh --help
```

| Flag | What it does |
| --- | --- |
| `--watch` | Clears the screen and redraws every 5 seconds. Press Ctrl+C to stop. |
| `--log FILE` | Appends a plain-text snapshot to `FILE`. ANSI colors are removed. |
| `--config FILE` | Reads warning and critical thresholds from `FILE`. |
| `--no-color` | Prints status words without ANSI colors. |
| `-h`, `--help` | Prints the usage text. |

You can also set `DASHBOARD_CONFIG` to a config path, or `NO_COLOR=1` to turn colors off.

`--watch` is a loop inside the script. It uses `clear` and `sleep 5`. It does not call `watch dashboard.sh --watch`, which would restart itself forever.

## What each section shows

| Section | Content |
| --- | --- |
| System Info | Hostname, `uname -a`, uptime, date and time |
| CPU & Memory | Load average, CPU percent, total/used/free memory, swap, ASCII bars |
| Disk Usage | Every mounted filesystem from `df -h`, plus bars for `/` and the fullest mount |
| Top Processes | Top 5 by CPU and top 5 by memory |
| Network | Primary interface, its IPv4 address, default gateway, established TCP count |
| Services | SSH, cron, and firewall. Active is green, failed is red, anything else is yellow |
| Logins & Users | `who` and the last 3 records from `last` |
| Recent Log Errors | `journalctl -p err -n 5` |

Colors follow the thresholds in `dashboard.conf`:

- Green `OK`: below the warning value
- Yellow `WARNING`: at or above warning, below critical
- Red `CRITICAL`: at or above critical

CPU, memory, swap, and disk thresholds are percentages. Load thresholds are per CPU (`1.00` means one busy core). `CONN_WARN` and `CONN_CRIT` are counts of established TCP connections.

The config file is parsed as `KEY=value` lines. It is not sourced, so a line in that file cannot run a command.

## Fedora and Ubuntu

The same script runs on both course VMs. These names differ:

| Check | Fedora | Ubuntu Server |
| --- | --- | --- |
| SSH | `sshd.service` | `ssh.service` |
| Scheduler | `crond.service` | `cron.service` |
| Firewall | `firewalld.service` | `ufw.service` (or `nftables.service`) |

The script reads `/etc/os-release` and tries the native unit name first. If a unit is not installed, that row says so and the other sections still print. When one of the three is missing, the script also reports `systemd-journald` so a systemd host still shows a real service state.

CPU percent is sampled from `/proc/stat` for about a quarter of a second, so the script does not need `mpstat` or `sysstat`. Established connections come from `ss` when it exists, and from `/proc/net/tcp` otherwise. Memory comes from `free -b`, with `/proc/meminfo` as a fallback.

## Missing commands

If `df`, `ps`, `ip`, `systemctl`, `journalctl`, `who`, `last`, or another command is missing, that section prints `[unavailable]` and explains which command was missing. The script still exits 0 after a normal run. It exits 1 only for a bad option or a `--config` file that does not exist.

Some readings need root. If `journalctl` cannot open the journal, the error text from `journalctl` is shown in that section.

## Screenshots for submission

Run the script in a terminal on each VM and capture the whole window. The first lines include the OS name from `/etc/os-release`, which makes the Fedora shot and the Ubuntu shot easy to tell apart.

```bash
./dashboard.sh --no-color
./dashboard.sh
```

Use a wide terminal, about 100 columns, so the `uname -a` line and the `df` table stay on one line each.

These screenshots have to come from the VMs. A run on Windows or Git Bash is not a substitute.

## Git history

The repo needs at least three commits, and the submitted git log needs every group member as an author. One GitHub repo is the shared copy. Pedro Gonzales clones that repo, edits his part, and pushes. A second repo does not merge cleanly with this history.

```bash
git config user.name "Pedro Gonzales"
git add dashboard.sh
git commit -m "Describe the Ubuntu service names and the watch loop"
git push
```

Screenshot this command so both names are visible:

```bash
git log --oneline --format="%h %an %s"
```

Do not rewrite the author of someone else's commit.

## Who did which part

Estefan Ramos took the Fedora side and the readings that describe the machine itself. Pedro Gonzales took the Ubuntu side and the readings that describe what the machine is doing right now.

| Name | What they own | What they present |
| --- | --- | --- |
| Estefan Ramos | System info, CPU, memory, disk, and the Fedora service names (`sshd`, `crond`, `firewalld`). Thresholds live in `dashboard.conf`. Functions: `show_system_info`, `show_cpu_memory`, `cpu_usage_percent`, `show_disk`. | Slides 2 and 3. Slide 3 is the Fedora demo. |
| Pedro Gonzales | The Ubuntu service names (`ssh`, `cron`, `ufw` or `nftables`), top processes, network, logins, journal errors, `--watch`, and `--log`. Functions: `show_services`, `show_top_processes`, `show_network`, `show_logins`, `show_log_errors`, `watch_loop`. | Slides 4, 5, and 6. Slide 4 is the Ubuntu Server demo. |

Slide 1 lists both names. Estefan opens. Pedro takes the Ubuntu demo, the code, and the challenges. Both should be ready for questions on their own functions.

## Project files

- `dashboard.sh` — the dashboard
- `dashboard.conf` — thresholds
- `README.md` — this file
- `Bash-Dashboard-Presentation.pptx` — 7 slides for the 8–10 minute presentation
