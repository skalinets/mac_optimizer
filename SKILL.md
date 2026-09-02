---
name: mac-optimizer
description: Analyze macOS performance — CPU, memory, swap, processes, browsers, containers — and battery drain, then provide actionable optimization recommendations. Use when the user asks to check Mac performance, optimize their system, diagnose slowness, audit running processes, or asks why the battery drains fast.
user-invocable: true
allowed-tools: Bash(bash *), Agent
metadata:
  author: skalinets
  version: "1.2.0"
  license: MIT
---

# Mac Performance Optimizer

Analyzes the current state of a macOS system and provides actionable optimization recommendations.

## When to Use

- User asks to "check performance", "optimize my Mac", "why is my Mac slow"
- User wants to audit running processes, memory, or CPU usage
- User asks for system health check or resource analysis
- User says the battery drains fast, lasts a few hours, or asks what is eating power (see "Battery Mode" below)

## How to Run

Run the analysis script (the path is relative to where this skill is installed):

```bash
bash "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$HOME/.claude/skills/mac-optimizer")")/mac-optimize.sh"
```

Or if the skill is installed via `npx skills add`:

```bash
bash "$HOME/.claude/skills/mac-optimizer/mac-optimize.sh"
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

# Disable a launch daemon (modern macOS — do NOT use launchctl unload)
sudo launchctl bootout system /Library/LaunchDaemons/com.example.plist
# Prevent it from loading on next boot
sudo launchctl disable system/com.example.service

# List and kill heavy processes
kill -TERM <PID>
```

## Battery Mode

Use this when the complaint is battery life, not slowness. Two steps: collect, then fan out to a small agent team.

### 1. Collect

```bash
bash "$HOME/.claude/skills/mac-optimizer/mac-battery.sh"
```

No sudo needed. The script reports battery health (capacity vs design, cycles, live discharge in watts, projected runtime), the battery pmset profile, processes ranked by power impact, browser renderer hogs, chat and sync apps, known traps (Activity Monitor open, `caffeinate`, many Claude Code sessions, tmux pane count, long uptime), sleep assertions, and 24 h wake counts.

### 2. Fan out to the agent team

Spawn all four in one message so they run in parallel. Use the Agent tool with `subagent_type: general-purpose`. For each, read `agents/<name>.md` in this skill directory, take `model:` from the frontmatter, and use the markdown body as the prompt. Pass the relevant script sections in the prompt so the agent does not have to re-collect.

| Agent | Model | Why that model |
|---|---|---|
| `battery-health-analyst` | haiku | Arithmetic and fixed thresholds on 7 numbers. No judgment. |
| `sleep-wake-auditor` | haiku | Counts log lines, maps reasons to known pmset flags. |
| `power-hog-hunter` | sonnet | Must identify unknown processes and judge whether their usage is legitimate. |
| `background-services-auditor` | sonnet | Must know what third-party agents and apps are for. |

Do not spawn the two haiku agents if the script already shows a healthy battery and under 10 dark wakes. Do the synthesis yourself on the main model. Do not delegate it.

If the installed agents exist in `~/.claude/agents/` (see README), use `subagent_type: <name>` instead and skip the prompt copying.

### 3. What the agents cannot do

- Map a browser renderer PID to a tab. The user must open the browser task manager.
- Measure per-process energy in watts, or GPU and display power. That needs `sudo powermetrics`. Give the user the command and offer to interpret the output.
- Run any `sudo` command. Print it, tell the user to run it.

### 4. Synthesis

Merge the four reports into one answer:

1. **Verdict line**: hardware share vs software share of the shortfall, from the health analyst.
2. **Watts table**: current draw, projected runtime, and the top 5 hogs with expected recovery.
3. **Actions** ordered by watts recovered per effort. Quitting an app beats a pmset change beats a launch agent cleanup.
4. **Battery replacement** as its own item when health is under 80%. Do not bury it.

Thresholds: draw under 10 W is normal, 10-20 W is moderate, over 20 W means software is burning power. Under 80% capacity or "Service Recommended" means a new battery is the single largest fix available.

**Important:** `launchctl unload` is deprecated and fails on modern macOS. Always use `launchctl bootout` / `launchctl disable` instead. These commands require `sudo` — tell the user to run them in their terminal directly.

Always warn the user before suggesting `kill` — prefer `osascript -e 'quit app'` for GUI apps.
