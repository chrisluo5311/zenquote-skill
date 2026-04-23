#!/bin/bash
#
# ZenQuote - Daily inspirational quotes from ZenQuotes.io
# Free API only - no premium features
#

set -e

API_BASE="https://zenquotes.io/api"
CONFIG_FILE="${ZENQUOTE_CONFIG:-$HOME/.openclaw/skills/zenquote/config.json}"

# Ensure config directory exists
mkdir -p "$(dirname "$CONFIG_FILE")"

# Initialize default config if not exists
init_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" << 'EOF'
{
  "mode": "free"
}
EOF
  fi
}

# Fetch quote from API
fetch_quote() {
  local mode="${1:-random}"
  local url=""
  
  case "$mode" in
    today|daily)
      url="${API_BASE}/today"
      ;;
    random)
      url="${API_BASE}/random"
      ;;
    quotes)
      url="${API_BASE}/quotes"
      ;;
    *)
      url="${API_BASE}/random"
      ;;
  esac
  
  # Fetch and parse response
  local response=$(curl -s "$url" 2>/dev/null || echo "[]")
  echo "$response"
}

# Fetch quote image URL
fetch_image() {
  echo "${API_BASE}/image"
}

# Format quote for display
format_quote() {
  local json="$1"
  local idx="${2:-0}"
  
  local quote=$(echo "$json" | jq -r ".[$idx].q // empty")
  local author=$(echo "$json" | jq -r ".[$idx].a // empty")
  
  if [[ -z "$quote" ]]; then
    echo "No quote available"
    return 1
  fi
  
  cat << EOF
🌟 Daily Inspiration

"${quote}"

— ${author}

━━━━━━━━━━━━━━━━━━
Provided by ZenQuotes API
EOF
}

# Get daily quote
get_daily_quote() {
  local response=$(fetch_quote "today")
  local formatted=$(format_quote "$response" 0)
  echo "$formatted"
}

# Get random quote
get_random_quote() {
  local response=$(fetch_quote "random")
  local formatted=$(format_quote "$response" 0)
  echo "$formatted"
}

# Get multiple quotes
get_quotes() {
  local count="${1:-5}"
  local response=$(fetch_quote "quotes")
  
  echo "🌟 Inspirational Quotes"
  echo ""
  
  for i in $(seq 0 $((count - 1))); do
    local quote=$(echo "$response" | jq -r ".[$i].q // empty")
    local author=$(echo "$response" | jq -r ".[$i].a // empty")
    
    if [[ -n "$quote" ]]; then
      echo "$((i + 1)). \"${quote}\""
      echo "   — ${author}"
      echo ""
    fi
  done
  
  echo "━━━━━━━━━━━━━━━━━━"
  echo "Provided by ZenQuotes API"
}

# Setup daily cron job
setup_daily_cron() {
  local chat_id="$1"
  local account_id="${2:-default}"
  
  if [[ -z "$chat_id" ]]; then
    echo '{"error": "Chat ID required"}'
    return 1
  fi
  
  # Create cron job JSON
  local cron_config="$HOME/.openclaw/cron/zenquote-daily.json"
  
  cat > "$cron_config" << EOF
{
  "name": "zenquote-daily",
  "enabled": true,
  "schedule": {
    "kind": "cron",
    "expr": "0 9 * * *",
    "tz": "Asia/Taipei"
  },
  "payload": {
    "kind": "agentTurn",
    "message": "Send daily inspirational quote from ZenQuotes API to telegram:${chat_id} using the zenquote skill. Use /zenQuote today command.",
    "model": "opencode-go/kimi-k2.5"
  },
  "delivery": {
    "mode": "announce",
    "channel": "telegram",
    "to": "${chat_id}",
    "accountId": "${account_id}"
  }
}
EOF
  
  echo "{\"setup\": true, \"message\": \"Daily quote scheduled for 9:00 AM\", \"chat_id\": \"${chat_id}\"}"
}

# CLI Main
main() {
  init_config
  
  local cmd="${1:-help}"
  shift || true
  
  case "$cmd" in
    today|daily)
      get_daily_quote
      ;;
    random)
      get_random_quote
      ;;
    quotes)
      get_quotes "$1"
      ;;
    image)
      local img_url=$(fetch_image)
      echo "{\"image_url\": \"${img_url}\"}"
      ;;
    setup)
      local chat_id="$1"
      local account_id="${2:-default}"
      setup_daily_cron "$chat_id" "$account_id"
      ;;
    help|*)
      cat << 'HELP'
ZenQuote - Daily Inspirational Quotes

Usage: zenquote <command> [args]

Commands:
  today                    Get today's quote
  random                   Get random quote  
  quotes [count]           Get multiple quotes (default 5)
  image                    Get quote image URL
  setup <chat_id> [account] Setup daily quote cron job at 9:00 AM

Free API Limits:
  - 5 requests per 30 seconds
  - Attribution required when displaying quotes

Examples:
  zenquote today
  zenquote random
  zenquote quotes 3
  zenquote setup 8248485303

API: https://zenquotes.io/
HELP
      ;;
  esac
}

main "$@"
