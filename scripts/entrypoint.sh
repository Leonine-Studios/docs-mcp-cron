#!/bin/bash
set -e

CONFIG_FILE="/config.json"

echo "========================================"
echo "Cron-based Docs MCP Server"
echo "========================================"

# Validate config file exists and is non-empty
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found at $CONFIG_FILE"
    echo "Please mount a config.json file to /config.json"
    echo "Example: docker run -v ./config.json:/config.json:ro ..."
    exit 1
fi

if [ ! -s "$CONFIG_FILE" ]; then
    echo "ERROR: Config file at $CONFIG_FILE is empty"
    exit 1
fi

# Validate JSON syntax
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "ERROR: Invalid JSON in $CONFIG_FILE"
    exit 1
fi

# Validate required fields
if ! jq -e '.websites' "$CONFIG_FILE" >/dev/null 2>&1; then
    echo "ERROR: Config must contain 'websites' array"
    exit 1
fi

echo "✓ Config file validated successfully"

# Extract global cron schedule (default to 2 AM if not specified)
GLOBAL_CRON_SCHEDULE=$(jq -r '.["global-settings"].cronSchedule // "0 2 * * *"' "$CONFIG_FILE")
echo "Global cron schedule: $GLOBAL_CRON_SCHEDULE"

# Build crontab entries for each enabled website
CRON_ENTRIES=""
ENABLED_COUNT=0

# Export environment variables for cron (cron doesn't inherit environment)
ENV_VARS_FILE="/tmp/cron_env_vars"
cat > "$ENV_VARS_FILE" << EOF
export OPENAI_API_KEY=${OPENAI_API_KEY}
export DOCS_MCP_TELEMETRY=${DOCS_MCP_TELEMETRY:-false}
export DOCS_MCP_EMBEDDING_MODEL=${DOCS_MCP_EMBEDDING_MODEL:-openai:text-embedding-3-small}
export DOCS_MCP_SCRAPER_DOCUMENT_MAX_SIZE=${DOCS_MCP_SCRAPER_DOCUMENT_MAX_SIZE}
export PATH=/usr/local/bin:/usr/bin:/bin
EOF

echo ""
echo "Configuring cron jobs for enabled websites:"
echo "--------------------------------------------"

# Process each website
jq -c '.websites[] | select(.enabled == true)' "$CONFIG_FILE" | while IFS= read -r website; do
    NAME=$(echo "$website" | jq -r '.name')
    URL=$(echo "$website" | jq -r '.url')
    
    # Get website-specific cron schedule or fall back to global
    CRON_SCHEDULE=$(echo "$website" | jq -r '.settings.cronSchedule // empty')
    if [ -z "$CRON_SCHEDULE" ]; then
        CRON_SCHEDULE="$GLOBAL_CRON_SCHEDULE"
    fi
    
    echo "  • $NAME"
    echo "    URL: $URL"
    echo "    Schedule: $CRON_SCHEDULE"
    
    # Add cron entry for this website with environment variables
    echo "$CRON_SCHEDULE . /tmp/cron_env_vars; /usr/local/bin/scrape-or-refresh.sh \"$NAME\" >> /var/log/docs-mcp-refresh.log 2>&1" >> /tmp/crontab.txt
    
    ENABLED_COUNT=$((ENABLED_COUNT + 1))
done

# Install crontab if we have any entries
if [ -f /tmp/crontab.txt ]; then
    # Install the crontab
    crontab /tmp/crontab.txt
    rm /tmp/crontab.txt
    
    echo ""
    echo "✓ Installed cron jobs for $ENABLED_COUNT website(s)"
else
    echo ""
    echo "⚠ No enabled websites found in config"
fi

# Start cron daemon
echo ""
echo "Starting cron daemon..."
cron

# Start config file watcher in background
echo ""
echo "Starting config.json file watcher..."
/usr/local/bin/watch-config.sh >> /var/log/docs-mcp-config-watcher.log 2>&1 &
echo "✓ Config watcher started (logs: /var/log/docs-mcp-config-watcher.log)"

# Display installed cron jobs
echo ""
echo "Installed cron jobs:"
echo "--------------------------------------------"
crontab -l || echo "(no cron jobs installed)"

# Change to app directory
cd /app

# Execute the MCP server with the original base image command
echo ""
echo "========================================"
echo "Starting MCP server..."
echo "========================================"
echo "Document max size: ${DOCS_MCP_SCRAPER_DOCUMENT_MAX_SIZE:-default} bytes"
exec node --enable-source-maps dist/index.js "$@"
