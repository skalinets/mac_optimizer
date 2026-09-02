#!/usr/bin/env bash
# mac-battery.sh — Collects macOS battery drain data for analysis.
# No sudo required. Uses only built-in tools (pmset, ioreg, top, ps, system_profiler).
set -uo pipefail

redact() {
    sed -E 's/(token|key|password|secret|credential|auth)=[^ ]*/\1=REDACTED/gi'
}

# Read one integer key from the AppleSmartBattery plist (signed values come out correct here,
# unlike plain `ioreg -rn` which prints negatives as unsigned 64-bit).
BATT_PLIST=$(ioreg -rn AppleSmartBattery -a 2>/dev/null)
batt_int() {
    printf '%s\n' "$BATT_PLIST" | awk -v k="<key>$1</key>" '
        index($0, k) { getline; gsub(/[^-0-9]/, ""); print; exit }'
}

echo "WARNING: This output may contain sensitive information (process names, paths)."
echo "Review before sharing publicly."
echo ""

echo "=== POWER SOURCE ==="
pmset -g batt 2>/dev/null || true
uptime

echo ""
echo "=== BATTERY HEALTH (ioreg) ==="
design=$(batt_int DesignCapacity)
maxcap=$(batt_int AppleRawMaxCapacity)
curcap=$(batt_int AppleRawCurrentCapacity)
cycles=$(batt_int CycleCount)
amps=$(batt_int InstantAmperage)
[ -z "$amps" ] && amps=$(batt_int Amperage)
volts=$(batt_int Voltage)
temp=$(batt_int Temperature)
if [ -n "$design" ] && [ -n "$maxcap" ] && [ "$design" -gt 0 ]; then
    echo "Design capacity:   ${design} mAh"
    echo "Max capacity now:  ${maxcap} mAh ($(( maxcap * 100 / design ))% of design)"
    echo "Current charge:    ${curcap:-?} mAh"
    echo "Cycle count:       ${cycles:-?}"
    [ -n "$temp" ] && echo "Temperature:       $(( temp / 100 )).$(( temp % 100 )) C"
    if [ -n "$amps" ] && [ -n "$volts" ] && [ "$amps" -lt 0 ]; then
        draw_ma=$(( -amps ))
        # milliwatts = mA * mV / 1000
        draw_mw=$(( draw_ma * volts / 1000 ))
        echo "Discharge current: ${draw_ma} mA @ ${volts} mV = $(( draw_mw / 1000 )).$(( (draw_mw % 1000) / 100 )) W"
        if [ -n "$curcap" ] && [ "$draw_ma" -gt 0 ]; then
            mins=$(( curcap * 60 / draw_ma ))
            full_mins=$(( maxcap * 60 / draw_ma ))
            echo "Est. remaining:    $(( mins / 60 ))h $(( mins % 60 ))m at current draw"
            echo "Est. full-charge:  $(( full_mins / 60 ))h $(( full_mins % 60 ))m at current draw"
        fi
    elif [ -n "$amps" ] && [ "$amps" -ge 0 ]; then
        echo "Not discharging (on AC or idle). Unplug and re-run for drain figures."
    fi
else
    echo "No battery data (desktop Mac or ioreg unavailable)"
fi
system_profiler SPPowerDataType 2>/dev/null | grep -E "Condition|Maximum Capacity|Cycle Count" | sed 's/^ *//' || true

echo ""
echo "=== PMSET BATTERY PROFILE ==="
pmset -g custom 2>/dev/null | awk '/^Battery Power:/{p=1;next} /^AC Power:/{p=0} p' | grep -E "lowpowermode|powernap|tcpkeepalive|displaysleep|sleep |lessbright|womp" || true

echo ""
echo "=== TOP PROCESSES BY POWER IMPACT (top -o power, 2nd sample) ==="
top -l 2 -s 2 -o power -stats pid,command,cpu,power,mem,time -n 20 2>/dev/null \
    | awk '/^PID/{c++} c==2' | redact || true

echo ""
echo "=== LOAD & CPU HOGS (ps) ==="
ps auxc -r 2>/dev/null | head -12 | redact || true

echo ""
echo "=== BROWSER RENDERER HOGS (>1% CPU) ==="
ps -eo pid,%cpu,rss,etime,comm 2>/dev/null | grep -iE "Chrome Helper|Brave Browser Helper|Microsoft Edge Helper|Arc Helper|Firefox|Safari|WebContent" \
    | awk '$2>1.0 {printf "PID:%s CPU:%s%% RSS:%dMB ELAPSED:%s %s\n", $1, $2, $3/1024, $4, $5}' | head -15 || true
echo "(Which tab a renderer belongs to is not visible from the CLI. Use the browser's task manager.)"

echo ""
echo "=== ELECTRON / CHAT / SYNC APPS RUNNING ==="
ps -eo %cpu=,rss=,comm= 2>/dev/null \
    | grep -iE "Slack|Discord|Telegram|WhatsApp|Viber|Signal|Teams|Zoom|Notion|Spotify|Dropbox|OneDrive|Google Drive|CloudStorage|Creative Cloud|Adobe|OpenVPN|Tailscale|Docker|OrbStack|Screen Sharing|iPhone Mirroring" \
    | grep -vE "Helper|Renderer|Updater|Extension|appex" \
    | awk '{cpu=$1; rss=$2; $1=""; $2=""; n=$0; sub(/.*\//, "", n); printf "%-6s%% CPU  %5dMB  %s\n", cpu, rss/1024, n}' | sort -rn | head -15 || true

echo ""
echo "=== KNOWN BATTERY TRAPS ==="
if pgrep -q "Activity Monitor"; then
    sm=$(ps -eo %cpu,comm | grep -w sysmond | awk '{print $1}')
    echo "Activity Monitor is OPEN -> sysmond at ${sm:-?}% CPU. Close Activity Monitor."
fi
ps -eo pid=,args= 2>/dev/null | awk '$2=="caffeinate" {print "caffeinate running: " $0}' || true
ct=$(pgrep -f "^claude|/claude " 2>/dev/null | wc -l | tr -d ' ')
[ "$ct" -gt 0 ] && echo "Claude Code sessions: $ct  (sum CPU: $(ps -eo %cpu,args | grep -E '(^| )claude( |$)' | grep -v grep | awk '{s+=$1} END{print s+0}')%)"
tp=$(tmux list-panes -a 2>/dev/null | wc -l | tr -d ' ')
[ "${tp:-0}" -gt 0 ] && echo "tmux panes: $tp"
echo "Uptime: $(uptime | sed -E 's/.*up ([^,]*,[^,]*),.*/\1/')"

echo ""
echo "=== SLEEP ASSERTIONS (what keeps the Mac awake) ==="
pmset -g assertions 2>/dev/null | grep -E "^\s+pid " | redact | head -15 || true

echo ""
echo "=== WAKE EVENTS (last 24h) ==="
today=$(date +%Y-%m-%d); yday=$(date -v-1d +%Y-%m-%d)
wl=$(pmset -g log 2>/dev/null | grep -E "^($today|$yday)" | grep -E "Wake|DarkWake" || true)
echo "Dark wakes: $(printf '%s\n' "$wl" | grep -c DarkWake || true)"
echo "Full wakes: $(printf '%s\n' "$wl" | grep -cE '^[^ ]+ [^ ]+ [^ ]+ Wake ' || true)"
echo "Dark wake reasons:"
printf '%s\n' "$wl" | grep DarkWake | grep -oE "due to [^ ]+ [^ ]+" | sort | uniq -c | sort -rn | head -5
echo "Last 5 wakes:"
printf '%s\n' "$wl" | tail -5 | cut -c1-140

echo ""
echo "=== THERMAL ==="
pmset -g therm 2>/dev/null || true

echo ""
echo "=== DISPLAYS ==="
system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Display Type|Resolution|Connection Type" | sed 's/^ *//' || true

echo ""
echo "=== OPTIONAL: DEEPER DATA (needs sudo, run manually) ==="
echo "sudo powermetrics --samplers cpu_power,gpu_power,tasks --show-process-energy -i 5000 -n 2"
