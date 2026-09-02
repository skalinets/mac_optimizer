# Mac Optimizer

A Claude Code skill that analyzes macOS performance and provides actionable optimization recommendations.

## What It Does

Collects and analyzes:

- CPU and memory usage, swap pressure, compressor state
- Browser process bloat (Chrome, Brave, Safari, Firefox, Arc, Edge)
- Claude Code session count and resource usage
- Docker / OrbStack container runtimes
- Launch daemons and agents from third-party apps
- Disk space, system uptime, power settings
- Battery drain: health vs design capacity, live discharge in watts, processes by power impact, dark wakes, sleep assertions

Then provides prioritized recommendations (HIGH / MEDIUM / LOW impact) with copy-pasteable commands.

## Installation

### Option 1: npx skills (recommended)

```bash
npx skills add skalinets/mac_optimizer -g -y
```

The `-g` flag installs globally (available across all projects). The `-y` skips confirmation prompts.

### Option 2: Symlink from cloned repo

```bash
git clone https://github.com/skalinets/mac_optimizer.git ~/work/mac_optimizer
ln -sfn ~/work/mac_optimizer ~/.claude/skills/mac-optimizer
```

### Option 3: Copy into skills directory

```bash
git clone https://github.com/skalinets/mac_optimizer.git
cp -r mac_optimizer ~/.claude/skills/mac-optimizer
```

> **Note:** After installation, restart Claude Code or start a new session for the skill to be available.

## Usage

In any Claude Code session, type:

```
/mac-optimizer
```

Claude will run the analysis script and return a full performance report with recommendations.

You can also trigger it conversationally:

- "Check my Mac performance"
- "Why is my Mac slow?"
- "Optimize my system"

## Battery Mode

Ask "why does my battery drain so fast?" and the skill switches to battery mode. It runs `mac-battery.sh`, then fans out to four agents in parallel:

| Agent | Model | Job |
|---|---|---|
| battery-health-analyst | haiku | Hardware health, watts, hardware vs software share of the shortfall |
| sleep-wake-auditor | haiku | Dark wakes, sleep assertions, `pmset -b` fixes |
| power-hog-hunter | sonnet | Which processes burn power now, what they are, how to stop them |
| background-services-auditor | sonnet | Launch agents, login items, chat/sync/VPN apps worth disabling |

The two data-parsing agents run on Haiku because their work is arithmetic against fixed thresholds. The two that must recognize unknown software run on Sonnet. Synthesis stays on the main model.

The agent prompts live in `agents/`. The skill reads them at runtime, so no extra install is needed. To address them by name from any session, copy them into your agents directory:

```bash
cp ~/.claude/skills/mac-optimizer/agents/*.md ~/.claude/agents/
```

Not possible without `sudo`: per-process watts, GPU and display power. The skill prints the `powermetrics` command for you to run yourself. Mapping a browser renderer to a tab is not possible from the CLI at all — use the browser's task manager.

## Running the Scripts Standalone

The analysis scripts can also be run directly in your terminal:

```bash
bash ~/.claude/skills/mac-optimizer/mac-optimize.sh
bash ~/.claude/skills/mac-optimizer/mac-battery.sh
```

These print raw system metrics without the AI-powered analysis.

## Requirements

- macOS (tested on Apple Silicon only; Intel Macs have not been tested)
- Claude Code CLI installed
- No additional dependencies — uses only built-in macOS tools (`ps`, `vm_stat`, `sysctl`, `df`, `pmset`, `ioreg`, `top`, etc.)
