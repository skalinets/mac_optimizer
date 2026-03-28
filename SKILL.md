---
name: mac-optimizer
description: Analyze macOS performance — CPU, memory, swap, processes, browsers, containers — and provide actionable optimization recommendations. Use when the user asks to check Mac performance, optimize their system, diagnose slowness, or audit running processes.
user-invocable: true
allowed-tools: Bash(mac-optimize:*)
---

# Mac Performance Optimizer

Analyzes the current state of a macOS system and provides actionable optimization recommendations.

## When to Use

- User asks to "check performance", "optimize my Mac", "why is my Mac slow"
- User wants to audit running processes, memory, or CPU usage
- User asks for system health check or resource analysis

## How to Run

Run the analysis script:

```bash
bash /Users/serhii/work/mac_optimizer/mac-optimize.sh
```

## How to Analyze the Output

After running the script, analyze the output and provide recommendations organized by impact level (HIGH / MEDIUM / LOW).

### Key Metrics to Evaluate

1. **Memory Pressure** — Check physical RAM vs used, swap usage, and compressor size.
   - Swap used > 50% of RAM = heavy pressure
   - Free memory < 500MB = critical
   - Compressor > 50% of RAM = system is struggling

2. **Browser Bloat** — Count browser processes and total RAM%.
   - >50 Chrome/Brave processes = too many tabs
   - Running multiple Chromium browsers = redundant RAM use
   - Recommend tab suspender extensions or closing tabs

3. **Claude Code Sessions** — Each session holds memory.
   - >3 idle sessions = recommend closing unused ones

4. **Container Runtimes** — Docker/OrbStack VMs consume significant RAM.
   - If not actively used, recommend stopping

5. **Launch Daemons & Agents** — Background services from unneeded apps.
   - Flag daemons for apps not actively used (TeamViewer, Zoom, unused updaters)
   - Flag duplicate functionality (e.g., two NTFS drivers)

6. **Long-Running Processes** — Processes with high accumulated CPU time.
   - May indicate memory leaks or runaway processes
   - Recommend restarting if uptime is excessive

7. **Disk Space** — Flag if < 20GB free.

8. **System Uptime** — If > 7 days, recommend a reboot to reclaim swap and reset compressor.

### Response Format

Present findings as:

1. **Summary table** — key metrics with status indicators
2. **Top consumers** — ranked list of what's using the most resources
3. **Recommendations** — grouped by HIGH / MEDIUM / LOW impact
4. **Quick wins** — copy-pasteable commands the user can run immediately

### Example Quick Win Commands

```bash
# Quit an app not in use
osascript -e 'quit app "AppName"'

# Purge inactive memory (temporary relief)
sudo purge

# Enable low power mode on battery
sudo pmset -b lowpowermode 1

# List and kill heavy processes
kill -TERM <PID>
```

Always warn the user before suggesting `kill` — prefer `osascript -e 'quit app'` for GUI apps.
