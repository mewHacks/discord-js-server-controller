# Discord Bot — GCP VM Control + Notifications

A Discord bot built with [Discord.js](https://discord.js.org/) that lets you **start**, **stop**, and **check the status** of a Google Cloud Compute Engine VM instance via slash commands. It also runs an [Express](https://expressjs.com/) server with webhook endpoints to push real-time server event notifications into a Discord channel.

---

## Project Structure

```
discordjs/
├── .env.example                # environment variable template
├── .gitignore
├── package.json
├── README.md
└── src/
    ├── index.js                # entry point — boots bot + Express
    ├── config.js               # env validation & export
    ├── bot/
    │   ├── bot.js              # Discord client & interaction handler
    │   ├── commands.js         # slash command definitions
    │   └── deploy-commands.js  # register commands with Discord API
    ├── server/
    │   └── server.js           # Express notification endpoints
    └── services/
        └── vmService.js        # GCP Compute Engine start/stop/status
```

---

## Prerequisites

- **Node.js** v18 or later
- A **Discord bot** with a token ([Discord Developer Portal](https://discord.com/developers/applications))
- A **Google Cloud** project with a Compute Engine VM instance
- **GCP authentication** — either:
  - Run `gcloud auth application-default login`, **or**
  - Set the `GOOGLE_APPLICATION_CREDENTIALS` env var to a service account key JSON path

---

## Setup

### 1. Clone & install

```bash
git clone <your-repo-url>
cd discordjs
npm install
```

### 2. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` and fill in every value:

| Variable | Description |
|---|---|
| `DISCORD_TOKEN` | Bot token from the Discord Developer Portal |
| `DISCORD_CLIENT_ID` | Application / Client ID |
| `DISCORD_GUILD_ID` | The server (guild) where commands are registered |
| `DISCORD_CHANNEL_ID` | Channel where notification embeds are sent |
| `GCP_PROJECT_ID` | Your Google Cloud project ID |
| `GCP_ZONE` | Zone of the VM (e.g. `us-central1-a`) |
| `GCP_INSTANCE_NAME` | Name of the Compute Engine VM instance |
| `EXPRESS_PORT` | Port for the Express server (default `3000`) |

### 3. Register slash commands (one-time)

```bash
npm run deploy-commands
```

### 4. Start the bot

```bash
npm start
```

You should see:

```
🤖  Discord bot logged in as YourBot#1234
🌐  Express server listening on port 3000
```

---

## Discord Slash Commands

| Command | Description |
|---|---|
| `/vm-start` | Starts the GCP VM instance and reports when it's running |
| `/vm-stop` | Stops the GCP VM instance and reports when it's stopped |
| `/vm-status` | Shows current status, external IP, machine type, and zone |

All responses use colour-coded rich embeds (🟢 running, 🔴 stopped, 🟠 stopping/staging, 🔵 provisioning).

---

## Express Notification Endpoints

The Express server listens on the configured port (default `3000`). Each `POST` endpoint sends a rich embed notification to the configured Discord channel.

| Method | Path | Body | Description |
|---|---|---|---|
| `GET` | `/health` | — | Health check (returns `{ status, uptime }`) |
| `POST` | `/notify/started` | — | Sends a **Server Started** notification |
| `POST` | `/notify/stopped` | — | Sends a **Server Stopped** notification |
| `POST` | `/notify/stopping` | — | Sends a **Server Stopping** notification |
| `POST` | `/notify/starting` | — | Sends a **Server Starting** notification |
| `POST` | `/notify/event` | `{ title, description, color? }` | Sends a custom event notification |

### Example — send a custom event

```bash
curl -X POST http://localhost:3000/notify/event \
  -H "Content-Type: application/json" \
  -d '{"title": "Backup Complete", "description": "Daily backup finished successfully.", "color": 65280}'
```

---

## Scripts

| Script | Command | Description |
|---|---|---|
| `start` | `npm start` | Run the bot + Express server |
| `deploy-commands` | `npm run deploy-commands` | Register slash commands with Discord |

---

## License

ISC
