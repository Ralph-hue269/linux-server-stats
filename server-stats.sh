#!/usr/bin/env bash
#
# server-stats.sh
# Analyses basic server performance stats on any Linux server.
#
# Usage: ./server-stats.sh
#

set -euo pipefail

# ---------- Helpers ----------

print_header() {
    echo
    echo "=================================================="
    echo " $1"
    echo "=================================================="
}

# ---------- 1. CPU Usage ----------

cpu_usage() {
    print_header "Total CPU Usage"

    # Read CPU stats twice with a short delay to calculate usage over an interval.
    read -r cpu user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1 _ < /proc/stat
    sleep 1
    read -r cpu user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 _ < /proc/stat

    prev_idle=$((idle1 + iowait1))
    idle=$((idle2 + iowait2))

    prev_non_idle=$((user1 + nice1 + system1 + irq1 + softirq1 + steal1))
    non_idle=$((user2 + nice2 + system2 + irq2 + softirq2 + steal2))

    prev_total=$((prev_idle + prev_non_idle))
    total=$((idle + non_idle))

    total_diff=$((total - prev_total))
    idle_diff=$((idle - prev_idle))

    cpu_percentage=$(awk -v total_diff="$total_diff" -v idle_diff="$idle_diff" \
        'BEGIN { if (total_diff == 0) print "0.00"; else printf "%.2f", (total_diff - idle_diff) / total_diff * 100 }')

    echo "CPU Usage: ${cpu_percentage}%"
}

# ---------- 2. Memory Usage ----------

memory_usage() {
    print_header "Total Memory Usage"

    free -h | awk '
        NR==1 { print "         " $1, $2, $3, $4, $5, $6, $7 }
        NR==2 {
            total=$2; used=$3; free=$4
            print $0
        }
    '

    # Percentage calculation (using /proc/meminfo for precision in KB)
    mem_total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    mem_available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
    mem_used=$((mem_total - mem_available))

    used_pct=$(awk -v used="$mem_used" -v total="$mem_total" 'BEGIN { printf "%.2f", used/total*100 }')
    free_pct=$(awk -v avail="$mem_available" -v total="$mem_total" 'BEGIN { printf "%.2f", avail/total*100 }')

    echo
    echo "Used: ${used_pct}% | Free: ${free_pct}%"
}

# ---------- 3. Disk Usage ----------

disk_usage() {
    print_header "Total Disk Usage"

    # Aggregate across all real filesystems (excluding tmpfs/devtmpfs/overlay snap mounts etc.)
    df -h --total -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | \
        awk 'NR==1 || /^total/'

    echo
    df -h --total -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | \
        awk '/^total/ { print "Used: " $5 " | Free: " $4 " (of " $2 " total)" }'
}

# ---------- 4. Top 5 Processes by CPU ----------

top_cpu_processes() {
    print_header "Top 5 Processes by CPU Usage"
    printf "%-10s %-25s %-8s %-8s\n" "PID" "COMMAND" "%CPU" "%MEM"
    ps axch -o pid,comm,pcpu,pmem --sort=-pcpu | head -n 5 | \
        awk '{ printf "%-10s %-25s %-8s %-8s\n", $1, $2, $3, $4 }'
}

# ---------- 5. Top 5 Processes by Memory ----------

top_mem_processes() {
    print_header "Top 5 Processes by Memory Usage"
    printf "%-10s %-25s %-8s %-8s\n" "PID" "COMMAND" "%CPU" "%MEM"
    ps axch -o pid,comm,pcpu,pmem --sort=-pmem | head -n 5 | \
        awk '{ printf "%-10s %-25s %-8s %-8s\n", $1, $2, $3, $4 }'
}

# ---------- Stretch: OS Version ----------

os_version() {
    print_header "OS Version"
    if [ -f /etc/os-release ]; then
        awk -F= '/^PRETTY_NAME=/ { gsub(/"/, "", $2); print $2 }' /etc/os-release
    else
        uname -a
    fi
}

# ---------- Stretch: Uptime ----------

uptime_stat() {
    print_header "Uptime"
    uptime -p 2>/dev/null || uptime
}

# ---------- Stretch: Load Average ----------

load_average() {
    print_header "Load Average (1m, 5m, 15m)"
    awk '{ print "1 min: " $1 "  5 min: " $2 "  15 min: " $3 }' /proc/loadavg
}

# ---------- Stretch: Logged In Users ----------

logged_in_users() {
    print_header "Logged In Users"
    who | awk '{ print $1, $2, $3, $4 }'
    echo
    echo "Total logged in sessions: $(who | wc -l)"
}

# ---------- Stretch: Failed Login Attempts ----------

failed_logins() {
    print_header "Failed Login Attempts"
    if command -v lastb >/dev/null 2>&1; then
        if [ "$(id -u)" -eq 0 ]; then
            count=$(lastb 2>/dev/null | grep -c '^')
            echo "Failed login attempts (from lastb): ${count:-0}"
        else
            echo "Run as root/sudo to view failed login attempts (requires access to btmp log)."
        fi
    else
        echo "lastb command not available on this system."
    fi
}

# ---------- Main ----------

main() {
    echo "Server Performance Stats - $(date)"
    cpu_usage
    memory_usage
    disk_usage
    top_cpu_processes
    top_mem_processes
    os_version
    uptime_stat
    load_average
    logged_in_users
    failed_logins
    echo
}

main
