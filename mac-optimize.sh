#!/usr/bin/env bash
# mac-optimize.sh — Collects macOS performance data for analysis
set -euo pipefail

echo "=== SYSTEM INFO ==="
sysctl -n machdep.cpu.brand_string
echo "Cores: $(sysctl -n hw.ncpu)"
echo "RAM: $(( $(sysctl -n hw.memsize) / 1073741824 )) GB"
sw_vers
uptime

echo ""
echo "=== MEMORY ==="
vm_stat
echo "---SWAP---"
sysctl vm.swapusage

echo ""
echo "=== TOP PROCESSES BY CPU ==="
ps aux -r | head -25

echo ""
echo "=== TOP PROCESSES BY MEMORY ==="
ps aux -m | head -25

echo ""
echo "=== PROCESS SUMMARY ==="
echo "Total processes: $(ps aux | wc -l | tr -d ' ')"
echo "Total threads: $(ps -M -e | wc -l | tr -d ' ')"

echo ""
echo "=== BROWSER PROCESSES ==="
for browser in "Google Chrome" "Brave Browser" "Firefox" "Safari" "Arc" "Microsoft Edge"; do
    count=$(ps aux | grep -i "$browser" | grep -v grep | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        mem=$(ps aux | grep -i "$browser" | grep -v grep | awk '{sum+=$4} END {printf "%.1f", sum}')
        cpu=$(ps aux | grep -i "$browser" | grep -v grep | awk '{sum+=$3} END {printf "%.1f", sum}')
        echo "$browser: $count processes, ${mem}% RAM, ${cpu}% CPU"
    fi
done

echo ""
echo "=== CLAUDE CODE SESSIONS ==="
ps aux | grep -w "claude" | grep -v grep | awk '{printf "PID:%s CPU:%s%% MEM:%s%% RSS:%dMB\n", $2, $3, $4, $6/1024}' || echo "None"

echo ""
echo "=== DISK USAGE ==="
df -h /
diskutil info / | grep -E "Free|Available|Purgeable" || true

echo ""
echo "=== POWER & THERMAL ==="
pmset -g 2>/dev/null | grep -E "lowpowermode|sleep|displaysleep" || true
pmset -g therm 2>/dev/null || true

echo ""
echo "=== LOGIN ITEMS ==="
osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null || echo "Unable to read"

echo ""
echo "=== USER LAUNCH AGENTS ==="
ls ~/Library/LaunchAgents/ 2>/dev/null || echo "None"

echo ""
echo "=== SYSTEM LAUNCH DAEMONS ==="
ls /Library/LaunchDaemons/ 2>/dev/null || echo "None"

echo ""
echo "=== HEAVY LONG-RUNNING PROCESSES (>1hr CPU time) ==="
ps aux | awk 'NR>1 {split($10,t,":"); if(t[1]>=60 || (t[1]>=1 && length(t)==3)) printf "PID:%s CPU_TIME:%s CMD:%s\n", $2, $10, $11}' | head -20 || true

echo ""
echo "=== DOCKER / VM ==="
if pgrep -q "Docker\|OrbStack\|colima\|qemu"; then
    echo "Container runtime detected:"
    ps aux | grep -E "Docker|OrbStack|colima|qemu" | grep -v grep | awk '{printf "PID:%s CPU:%s%% MEM:%s%% CMD:%s\n", $2, $3, $4, $11}'
else
    echo "No container runtime detected"
fi

echo ""
echo "=== NETWORK CONNECTIONS (established) ==="
netstat -an 2>/dev/null | grep ESTABLISHED | wc -l | tr -d ' '
echo "established connections"
