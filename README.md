# Discord Bot — GCP VM Controller

A Discord bot built with [Discord.js v14](https://discord.js.org/) that lets you **start**, **stop**, and **check the status** of a Google Cloud Compute Engine VM instance via slash commands. It also runs an [Express v5](https://expressjs.com/) webhook server to push real-time VM lifecycle notifications into a Discord channel.

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
  - [1. Clone & Install](#1-clone--install)
  - [2. Create a Discord Bot](#2-create-a-discord-bot)
  - [3. Configure Environment Variables](#3-configure-environment-variables)
  - [4. GCP Authentication](#4-gcp-authentication)
  - [5. Register Slash Commands](#5-register-slash-commands)
  - [6. Start the Bot](#6-start-the-bot)
- [Using the Launch Script](#using-the-launch-script)
- [Discord Slash Commands](#discord-slash-commands)
- [Express Notification API](#express-notification-api)
  - [Endpoints](#endpoints)
  - [Example Requests](#example-requests)
- [CI/CD — GitHub Actions](#cicd--github-actions)
- [Running as a systemd Service](#running-as-a-systemd-service)
- [Troubleshooting](#troubleshooting)
- [Tech Stack](#tech-stack)
- [License](#license)

---

## Features

| Category | Details |
|---|---|
| **VM Control** | Start, stop, and check status of a GCP Compute Engine VM directly from Discord |
| **Rich Embeds** | Colour-coded status embeds (🟢 Running, 🔴 Stopped, 🟠 Stopping/Staging, 🔵 Provisioning) |
| **Status Details** | Displays instance name, status, machine type, zone, and external IP |
| **Webhook Notifications** | Express REST API sends real-time VM lifecycle events to a Discord channel |
| **Custom Events** | Generic `/notify/event` endpoint for arbitrary notifications |
| **Health Check** | `GET /health` endpoint for uptime and liveness monitoring |
| **Env Validation** | Startup-time validation of all required environment variables with clear error messages |
| **GCP SA Key Support** | Optional `SA_KEY` env var auto-maps to `GOOGLE_APPLICATION_CREDENTIALS` |
| **CI/CD** | GitHub Actions workflow for automated deployment to a GCP VM via SSH |
| **Launch Script** | `start.sh` with pre-flight checks, dependency install, and multiple run modes |

---

## Architecture

```
┌─────────────────────────┐        ┌──────────────────────┐
│   Discord User          │        │  External Service    │
│   (slash commands)      │        │  (e.g. cron, script) │
└────────┬────────────────┘        └──────────┬───────────┘
         │ /vm-start, /vm-stop,               │ POST /notify/*
         │ /vm-status                         │
         ▼                                    ▼
┌─────────────────────────────────────────────────────────┐
│                   Node.js Process                       │
│  ┌─────────────────────┐   ┌──────────────────────────┐ │
│  │  Discord.js Client  │   │   Express Server (:3000) │ │
│  │  (bot/bot.js)       │◄──│   (server/server.js)     │ │
│  └────────┬────────────┘   └──────────────────────────┘ │
│           │  sendNotification()                         │
│           ▼                                             │
│  ┌─────────────────────┐                                │
│  │  VM Service          │                               │
│  │  (services/          │                               │
│  │   vmService.js)      │                               │
│  └────────┬─────────────┘                               │
└───────────┼─────────────────────────────────────────────┘
            │ @google-cloud/compute
            ▼
   ┌────────────────────┐
   │  Google Cloud       │
   │  Compute Engine API │
   └────────────────────┘
```

---

## Project Structure

```
discordjs/
├── .env.example                 # Environment variable template
├── .gitignore                   # Git ignore rules (.env, node_modules, SA keys)
├── .github/
│   └── workflows/
│       └── main.yml             # GitHub Actions CI/CD deploy pipeline
├── start.sh                     # Bash launch script with pre-flight checks
├── package.json                 # npm config, scripts, and dependencies
├── README.md                    # This file
└── src/
    ├── index.js                 # Entry point — boots Discord bot + Express server
    ├── config.js                # Loads .env, validates required vars, exports config
    ├── bot/
    │   ├── bot.js               # Discord client, interaction handler, embed builder
    │   ├── commands.js          # Slash command definitions (/vm-start, /vm-stop, /vm-status)
    │   └── deploy-commands.js   # One-time script to register commands with Discord API
    ├── server/
    │   └── server.js            # Express app — notification webhook endpoints
    └── services/
        └── vmService.js         # GCP Compute Engine SDK wrapper (start/stop/status)
```

---

## Prerequisites

| Requirement | Notes |
|---|---|
| **Node.js** | v18 or later ([download](https://nodejs.org/)) |
| **npm** | Comes bundled with Node.js |
| **Discord Bot** | Create one at the [Discord Developer Portal](https://discord.com/developers/applications) |
| **Google Cloud Project** | With a Compute Engine VM instance |
| **GCP Authentication** | One of the two options below |

### GCP Authentication Options

| Method | When to use |
|---|---|
| `gcloud auth application-default login` | Local development / personal machine |
| Service account key JSON (`SA_KEY` in `.env`) | Headless servers, CI/CD, containers |

---

## Setup

### 1. Clone & Install

```bash
git clone <your-repo-url>
cd discordjs
npm install
```

### 2. Create a Discord Bot

1. Go to the [Discord Developer Portal](https://discord.com/developers/applications) → **New Application**.
2. Under **Bot** → **Token** → **Reset Token** → copy the token.
3. Under **OAuth2** → **URL Generator**:
   - **Scopes**: `bot`, `applications.commands`
   - **Bot Permissions**: `Send Messages`, `Embed Links`
4. Open the generated URL to invite the bot to your server.
5. Note down your **Application ID** (= Client ID) and your **Guild ID** (right-click your server → Copy Server ID; requires Developer Mode in Discord settings).

### 3. Configure Environment Variables

```bash
cp .env.example .env
```

Edit `.env` and fill in every value:

| Variable | Required | Description |
|---|---|---|
| `DISCORD_TOKEN` | ✅ | Bot token from step 2 |
| `DISCORD_CLIENT_ID` | ✅ | Application (Client) ID |
| `DISCORD_GUILD_ID` | ✅ | Server (guild) where commands are registered |
| `DISCORD_CHANNEL_ID` | ✅ | Channel where notification embeds are posted |
| `GCP_PROJECT_ID` | ✅ | Your Google Cloud project ID |
| `GCP_ZONE` | ✅ | Zone of the VM (e.g. `us-central1-a`) |
| `GCP_INSTANCE_NAME` | ✅ | Name of the Compute Engine VM instance |
| `SA_KEY` | ✅ | Path to a GCP service account key JSON file |
| `EXPRESS_PORT` | ✅ | Port for the Express server (default: `3000`) |

### 4. GCP Authentication

**Option A — Application Default Credentials (local dev)**

```bash
gcloud auth application-default login
```

**Option B — Service Account Key (production / headless)**

1. In the GCP Console → **IAM & Admin** → **Service Accounts** → create a key (JSON).
2. Save the file (e.g. `gcp-sa-key.json`) in the project root (it's git-ignored).
3. Set `SA_KEY=./gcp-sa-key.json` in `.env`.

> The service account needs at minimum the **Compute Instance Admin (v1)** role (`roles/compute.instanceAdmin.v1`).

### 5. Register Slash Commands

This step only needs to be run **once**, or whenever you add/change slash command definitions:

```bash
npm run deploy-commands
```

You should see:

```
🔄  Registering 3 slash command(s)…
✅  Slash commands registered successfully.
```

### 6. Start the Bot

```bash
npm start
```

Expected output:

```
🤖  Discord bot logged in as YourBot#1234
🌐  Express server listening on port 3000
```

---

## Using the Launch Script

The provided `start.sh` automates pre-flight validation and startup. Make it executable first:

```bash
chmod +x start.sh
```

| Command | What it does |
|---|---|
| `./start.sh` | Validates environment → starts the bot |
| `./start.sh --deploy` | Validates → deploys slash commands → starts the bot |
| `./start.sh --deploy-only` | Validates → deploys slash commands → exits |
| `./start.sh --check` | Validates environment and dependencies only (dry run) |
| `./start.sh --help` | Shows usage information |

### Pre-flight checks performed

- ✅ Node.js v18+ is installed
- ✅ npm is available
- ✅ `node_modules/` exists (auto-runs `npm install` if missing)
- ✅ `.env` file exists
- ✅ All required environment variables are set and not placeholders
- ✅ GCP authentication is configured

---

## Discord Slash Commands

All three commands use deferred replies and colour-coded rich embeds.

| Command | Description | Embed Colour |
|---|---|---|
| `/vm-start` | Sends a start request to GCP, waits for the operation to complete, then confirms | 🔵 → 🟢 |
| `/vm-stop` | Sends a stop request to GCP, waits for the operation to complete, then confirms | 🟠 → 🔴 |
| `/vm-status` | Queries GCP and displays current status, name, machine type, zone, and external IP | Status-dependent |

### Status Colour Map

| VM Status | Colour | Hex |
|---|---|---|
| `RUNNING` | 🟢 Green | `#00C853` |
| `STOPPED` | 🔴 Red | `#D50000` |
| `STOPPING` | 🟠 Orange | `#FF6D00` |
| `STAGING` | 🟡 Amber | `#FFAB00` |
| `PROVISIONING` | 🔵 Blue | `#2979FF` |
| `SUSPENDING` | 🟠 Orange | `#FF6D00` |
| `SUSPENDED` | ⚪ Grey | `#9E9E9E` |
| `TERMINATED` | ⚫ Dark Grey | `#616161` |

---

## Express Notification API

The built-in Express server (default port `3000`) provides webhook endpoints so external services (cron jobs, startup scripts, monitoring) can push VM lifecycle notifications into your Discord channel as rich embeds.

### Endpoints

| Method | Path | Request Body | Embed Title | Embed Colour |
|---|---|---|---|---|
| `GET` | `/health` | — | _(returns JSON: `{ status, uptime }`)_ | — |
| `POST` | `/notify/started` | — | ✅  Server Started | 🟢 `#00C853` |
| `POST` | `/notify/stopped` | — | ⛔  Server Stopped | 🔴 `#D50000` |
| `POST` | `/notify/stopping` | — | 🛑  Server Stopping | 🟠 `#FF6D00` |
| `POST` | `/notify/starting` | — | 🚀  Server Starting | 🔵 `#2979FF` |
| `POST` | `/notify/event` | `{ title, description, color? }` | _(custom)_ | _(custom or default grey)_ |

### Example Requests

**Health check:**

```bash
curl http://localhost:3000/health
# → { "status": "ok", "uptime": 143.27 }
```

**Trigger a lifecycle notification:**

```bash
# Server started
curl -X POST http://localhost:3000/notify/started

# Server stopping
curl -X POST http://localhost:3000/notify/stopping
```

**Send a custom event:**

```bash
curl -X POST http://localhost:3000/notify/event \
  -H "Content-Type: application/json" \
  -d '{"title": "Backup Complete", "description": "Daily backup finished successfully.", "color": 65280}'
```

> **Tip:** You can call these endpoints from VM startup/shutdown scripts to get automatic Discord notifications when the VM boots or shuts down.

---

## CI/CD — GitHub Actions

The repository includes a GitHub Actions workflow (`.github/workflows/main.yml`) that automatically deploys the bot on every push to `main`.

### How it works

1. **Checks out** the repository.
2. **Authenticates** with GCP using a service account key stored in GitHub Secrets.
3. **SSH's into the VM** via `gcloud compute ssh`.
4. On the VM it: pulls the latest code (`git fetch` + `git reset --hard`), runs `npm install`, deploys slash commands, and restarts the systemd service.

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `GCP_SA_KEY` | Full JSON content of the GCP service account key |
| `GCP_VM_NAME` | Name of the target VM |
| `GCP_ZONE` | GCP zone (e.g. `asia-southeast1-c`) |
| `GCP_PROJECT_ID` | GCP project ID |
| `DEPLOY_PATH` | Absolute path on the VM where the bot is deployed |
| `SERVICE_NAME` | systemd service name for the bot |

---

## Running as a systemd Service

To keep the bot running persistently on a Linux VM, create a systemd unit file:

```bash
sudo nano /etc/systemd/system/discord-vm-bot.service
```

```ini
[Unit]
Description=Discord GCP VM Controller Bot
After=network.target

[Service]
Type=simple
User=<your-user>
WorkingDirectory=/path/to/discordjs
ExecStart=/usr/bin/node src/index.js
Restart=on-failure
RestartSec=10
EnvironmentFile=/path/to/discordjs/.env

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable discord-vm-bot
sudo systemctl start discord-vm-bot

# Check status
sudo systemctl status discord-vm-bot

# View logs
sudo journalctl -u discord-vm-bot -f
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `❌ Missing required env var: …` | `.env` file is missing or a required variable is empty | Copy `.env.example` to `.env` and fill in all values |
| `DiscordAPIError: Unknown Application` | Wrong `DISCORD_CLIENT_ID` | Verify the client ID in the Discord Developer Portal |
| `DiscordAPIError: Missing Access` | Bot lacks permissions or wrong `GUILD_ID` | Re-invite the bot with correct scopes; verify the guild ID |
| Slash commands don't appear | Commands haven't been registered | Run `npm run deploy-commands` |
| Slash commands appear but don't respond | Bot is offline or crashed | Check `npm start` output for errors |
| `Error: Could not load the default credentials` | No GCP auth configured | Run `gcloud auth application-default login` or set `SA_KEY` in `.env` |
| `Permission 'compute.instances.start' denied` | SA lacks Compute Admin role | Grant `roles/compute.instanceAdmin.v1` to the service account |
| Notifications not posting | Wrong `DISCORD_CHANNEL_ID` | Ensure the channel ID is correct and the bot has send-message access |
| `EADDRINUSE: address already in use` | Port conflict | Change `EXPRESS_PORT` in `.env` or kill the conflicting process |

---

## Tech Stack

| Dependency | Version | Purpose |
|---|---|---|
| [discord.js](https://discord.js.org/) | ^14.26.2 | Discord API client — slash commands, embeds, gateway |
| [@google-cloud/compute](https://cloud.google.com/nodejs/docs/reference/compute/latest) | ^6.9.0 | GCP Compute Engine SDK — start/stop/status |
| [express](https://expressjs.com/) | ^5.2.1 | HTTP server for notification webhooks |
| [dotenv](https://github.com/motdotla/dotenv) | ^17.4.1 | Load `.env` variables into `process.env` |

### npm Scripts

| Script | Command | Description |
|---|---|---|
| `start` | `npm start` | Run the bot + Express server |
| `deploy-commands` | `npm run deploy-commands` | Register slash commands with the Discord API |

---