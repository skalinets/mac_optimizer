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

Then provides prioritized recommendations (HIGH / MEDIUM / LOW impact) with copy-pasteable commands.

## Installation

### Option 1: Symlink (recommended for local use)

```bash
git clone https://github.com/skalinets/mac_optimizer.git ~/work/mac_optimizer
ln -sfn ~/work/mac_optimizer ~/.claude/skills/mac-optimizer
```

### Option 2: Copy into skills directory

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

## Running the Script Standalone

The analysis script can also be run directly in your terminal:

```bash
bash ~/work/mac_optimizer/mac-optimize.sh
```

This prints raw system metrics without the AI-powered analysis.

## Requirements

- macOS (tested on Apple Silicon only; Intel Macs have not been tested)
- Claude Code CLI installed
- No additional dependencies — uses only built-in macOS tools (`ps`, `vm_stat`, `sysctl`, `df`, `pmset`, etc.)
