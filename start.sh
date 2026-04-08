#!/usr/bin/env bash
# ============================================================================
#  start.sh — Launch script for the Discord GCP VM Controller Bot
# ============================================================================
#  Usage:
#    chmod +x start.sh
#    ./start.sh              # Run in foreground
#    ./start.sh --deploy     # Register slash commands, then start the bot
#    ./start.sh --help       # Show usage information
# ============================================================================

set -euo pipefail

# ─── Colour helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

info()  { echo -e "${BLUE}ℹ  $*${NC}"; }
ok()    { echo -e "${GREEN}✅  $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠  $*${NC}"; }
err()   { echo -e "${RED}❌  $*${NC}" >&2; }

# ─── Help ───────────────────────────────────────────────────────────────────
show_help() {
  cat <<EOF
Discord GCP VM Controller Bot — Launch Script

Usage:
  ./start.sh              Start the bot + Express server
  ./start.sh --deploy     Deploy slash commands first, then start the bot
  ./start.sh --deploy-only  Deploy slash commands and exit (don't start bot)
  ./start.sh --check      Validate environment and dependencies, then exit
  ./start.sh --help       Show this help message

Environment:
  The bot reads configuration from a .env file in the project root.
  Copy .env.example to .env and fill in all required values before starting.

Required environment variables:
  DISCORD_TOKEN         Bot token from the Discord Developer Portal
  DISCORD_CLIENT_ID     Application / Client ID
  DISCORD_GUILD_ID      Server (guild) ID for command registration
  DISCORD_CHANNEL_ID    Channel ID for notification embeds
  GCP_PROJECT_ID        Google Cloud project ID
  GCP_ZONE              Compute Engine zone (e.g. us-central1-a)
  GCP_INSTANCE_NAME     VM instance name

Optional:
  SA_KEY                Path to GCP service account key JSON
  EXPRESS_PORT          Express server port (default: 3000)
EOF
}

# ─── Resolve project root (directory containing this script) ────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

# ─── Pre-flight checks ─────────────────────────────────────────────────────
preflight() {
  local has_errors=0

  # 1. Node.js
  if ! command -v node &>/dev/null; then
    err "Node.js is not installed. Install v18+ from https://nodejs.org/"
    has_errors=1
  else
    NODE_VERSION="$(node -v)"
    NODE_MAJOR="${NODE_VERSION#v}"
    NODE_MAJOR="${NODE_MAJOR%%.*}"
    if [ "$NODE_MAJOR" -lt 18 ]; then
      err "Node.js $NODE_VERSION found but v18+ is required."
      has_errors=1
    else
      ok "Node.js $NODE_VERSION"
    fi
  fi

  # 2. npm
  if ! command -v npm &>/dev/null; then
    err "npm is not installed."
    has_errors=1
  else
    ok "npm $(npm -v)"
  fi

  # 3. node_modules
  if [ ! -d "$PROJECT_DIR/node_modules" ]; then
    warn "node_modules/ not found — running 'npm install'…"
    (cd "$PROJECT_DIR" && npm install)
    ok "Dependencies installed."
  else
    ok "node_modules/ present"
  fi

  # 4. .env file
  if [ ! -f "$PROJECT_DIR/.env" ]; then
    err ".env file not found. Copy .env.example to .env and fill in the values."
    has_errors=1
  else
    ok ".env file found"

    # Validate required env vars are set (non-empty) in .env
    local required_vars=(
      DISCORD_TOKEN
      DISCORD_CLIENT_ID
      DISCORD_GUILD_ID
      DISCORD_CHANNEL_ID
      GCP_PROJECT_ID
      GCP_ZONE
      GCP_INSTANCE_NAME
    )

    # Source the .env to check values (in a subshell to avoid leaking)
    while IFS='=' read -r key value; do
      # Skip comments and empty lines
      [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
      # Remove surrounding quotes
      value="${value%\"}"
      value="${value#\"}"
      value="${value%\'}"
      value="${value#\'}"
      export "$key=$value" 2>/dev/null || true
    done < "$PROJECT_DIR/.env"

    for var in "${required_vars[@]}"; do
      val="${!var:-}"
      if [ -z "$val" ] || [[ "$val" == your-* ]] || [[ "$val" == channel-id-* ]]; then
        err "  $var is missing or still set to the placeholder value."
        has_errors=1
      else
        ok "  $var is configured"
      fi
    done
  fi

  # 5. GCP authentication
  if [ -n "${SA_KEY:-}" ] && [ -f "${SA_KEY}" ]; then
    ok "GCP SA key found at $SA_KEY"
  elif [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    ok "GOOGLE_APPLICATION_CREDENTIALS is set"
  else
    warn "No explicit GCP service account key detected."
    warn "Ensure you have run 'gcloud auth application-default login' or set SA_KEY in .env"
  fi

  if [ "$has_errors" -eq 1 ]; then
    echo ""
    err "Pre-flight checks failed. Fix the issues above and try again."
    exit 1
  fi

  echo ""
  ok "All pre-flight checks passed!"
}

# ─── Deploy slash commands ──────────────────────────────────────────────────
deploy_commands() {
  info "Registering slash commands with the Discord API…"
  (cd "$PROJECT_DIR" && node src/bot/deploy-commands.js)
  ok "Slash commands deployed."
}

# ─── Start the bot ──────────────────────────────────────────────────────────
start_bot() {
  info "Starting Discord bot + Express server…"
  echo ""
  (cd "$PROJECT_DIR" && node src/index.js)
}

# ────────────────────────────────────────────────────────────────────────────
#  Main
# ────────────────────────────────────────────────────────────────────────────
main() {
  local action="${1:-start}"

  case "$action" in
    --help|-h)
      show_help
      exit 0
      ;;
    --check)
      info "Running pre-flight checks…"
      echo ""
      preflight
      exit 0
      ;;
    --deploy)
      info "Running pre-flight checks…"
      echo ""
      preflight
      echo ""
      deploy_commands
      echo ""
      start_bot
      ;;
    --deploy-only)
      info "Running pre-flight checks…"
      echo ""
      preflight
      echo ""
      deploy_commands
      exit 0
      ;;
    start|"")
      info "Running pre-flight checks…"
      echo ""
      preflight
      echo ""
      start_bot
      ;;
    *)
      err "Unknown option: $action"
      echo ""
      show_help
      exit 1
      ;;
  esac
}

main "$@"
