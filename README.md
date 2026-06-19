# Linux Server Stats

A simple, dependency-free Bash script that analyzes basic performance stats on any Linux server — CPU, memory, disk, and top resource-consuming processes.

Built as a hands-on project for learning Linux fundamentals: process management, `/proc` filesystem internals, and shell scripting.

## What it reports

- **Total CPU usage** — calculated from `/proc/stat` over a 1-second sampling interval
- **Total memory usage** — free vs. used, including percentage
- **Total disk usage** — free vs. used, including percentage
- **Top 5 processes by CPU usage**
- **Top 5 processes by memory usage**

**Stretch stats:**
- OS version
- System uptime
- Load average (1, 5, 15 min)
- Currently logged in users
- Failed login attempts

## Requirements

- Bash
- Standard Linux utilities: `ps`, `free`, `df`, `awk`, `who`
- No external dependencies or packages needed — works out of the box on most distros

## Usage

Clone the repo and run the script:

```bash
git clone git@github.com:Ralph-hue269/linux-server-stats.git
cd linux-server-stats
chmod +x server-stats.sh
./server-stats.sh
```

For live-updating stats every 5 seconds:

```bash
watch -n 5 ./server-stats.sh
```
(Press `q` or `Ctrl+C` to exit.)

For the failed login attempts section, run with `sudo` to get accurate results:

```bash
sudo ./server-stats.sh
```

## Sample output

```
Server Performance Stats - Fri Jun 19 12:14:19 UTC 2026

==================================================
 Total CPU Usage
==================================================
CPU Usage: 1.98%

==================================================
 Total Memory Usage
==================================================
         total used free shared buff/cache available 
Mem:           3.9Gi       210Mi       3.8Gi       4.2Mi        75Mi       3.7Gi

Used: 5.26% | Free: 94.74%

==================================================
 Total Disk Usage
==================================================
Filesystem      Size  Used Avail Use% Mounted on
total            20G   8.6G   11G  44% -

Used: 44% | Free: 11G (of 20G total)

==================================================
 Top 5 Processes by CPU Usage
==================================================
PID        COMMAND                   %CPU     %MEM    
1          systemd                   6.2      0.1     
491        rclone                    4.5      0.8     
...
```

## How it works

- **CPU usage** is calculated by reading `/proc/stat` twice, one second apart, and computing the percentage of non-idle time over that interval — a snapshot alone can't measure a rate, so two samples are required.
- **Memory usage** uses `free -h` for the readable summary, and cross-checks exact percentages against `/proc/meminfo`'s `MemAvailable` field (which correctly accounts for reclaimable cache, unlike a naive `total - free` calculation).
- **Disk usage** aggregates real filesystems via `df -h --total`, excluding virtual mounts like `tmpfs` and `overlay` to avoid noise.
- **Top processes** use `ps axch -o pid,comm,pcpu,pmem --sort=-pcpu` (or `-pmem`), sorted and trimmed to the top 5 with `head`.

## License

MIT
