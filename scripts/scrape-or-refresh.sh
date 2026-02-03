#!/bin/bash
set -e

# Set PATH for cron environment
export PATH=/usr/local/bin:/usr/bin:/bin:$PATH

CONFIG_FILE="/config.json"
TARGET_WEBSITE="$1"

# Helper function to get scraper setting with fallback logic
# Usage: get_scraper_setting <website_json> <setting_path>
get_scraper_setting() {
    local website_json="$1"
    local setting_path="$2"
    
    # Try website-specific setting first
    local value=$(echo "$website_json" | jq -r ".settings.scraper.$setting_path // empty")
    
    # Fall back to global setting
    if [ -z "$value" ]; then
        value=$(jq -r ".\"global-settings\".scraper.$setting_path // empty" "$CONFIG_FILE")
    fi
    
    echo "$value"
}

# Helper function to build scraper CLI arguments
build_scraper_args() {
    local website_json="$1"
    local args=""
    
    # Get scraper settings with fallback
    local max_pages=$(get_scraper_setting "$website_json" "maxPages")
    local max_depth=$(get_scraper_setting "$website_json" "maxDepth")
    local max_concurrency=$(get_scraper_setting "$website_json" "maxConcurrency")
    local page_timeout=$(get_scraper_setting "$website_json" "pageTimeoutMs")
    local browser_timeout=$(get_scraper_setting "$website_json" "browserTimeoutMs")
    local max_retries=$(get_scraper_setting "$website_json" "fetcher.maxRetries")
    local base_delay=$(get_scraper_setting "$website_json" "fetcher.baseDelayMs")
    
    # Build CLI arguments (only if specified, otherwise use image defaults)
    [ -n "$max_pages" ] && args="$args --max-pages $max_pages"
    [ -n "$max_depth" ] && args="$args --max-depth $max_depth"
    [ -n "$max_concurrency" ] && args="$args --max-concurrency $max_concurrency"
    [ -n "$page_timeout" ] && args="$args --page-timeout $page_timeout"
    [ -n "$browser_timeout" ] && args="$args --browser-timeout $browser_timeout"
    [ -n "$max_retries" ] && args="$args --max-retries $max_retries"
    [ -n "$base_delay" ] && args="$args --base-delay $base_delay"
    
    echo "$args"
}

# Process a single website
process_website() {
    local website_json="$1"
    local name=$(echo "$website_json" | jq -r '.name')
    local url=$(echo "$website_json" | jq -r '.url')
    
    echo ""
    echo "========================================"
    echo "Processing: $name"
    echo "URL: $url"
    echo "========================================"
    
    # Check if library already exists
    EXISTING_LIBS=$(node /app/dist/index.js list 2>/dev/null || echo "")
    
    # Build scraper arguments
    SCRAPER_ARGS=$(build_scraper_args "$website_json")
    
    if echo "$EXISTING_LIBS" | grep -q "^$name$"; then
        echo "Library exists - refreshing..."
        if [ -n "$SCRAPER_ARGS" ]; then
            echo "Using custom scraper settings: $SCRAPER_ARGS"
            node /app/dist/index.js refresh "$name" $SCRAPER_ARGS
        else
            echo "Using default scraper settings"
            node /app/dist/index.js refresh "$name"
        fi
    else
        echo "New library - performing initial scrape..."
        if [ -n "$SCRAPER_ARGS" ]; then
            echo "Using custom scraper settings: $SCRAPER_ARGS"
            node /app/dist/index.js scrape "$name" "$url" $SCRAPER_ARGS
        else
            echo "Using default scraper settings"
            node /app/dist/index.js scrape "$name" "$url"
        fi
    fi
    
    echo "✓ Completed: $name"
}

# Main script logic
echo "========================================"
echo "Docs MCP Scrape/Refresh Script"
echo "Time: $(date)"
echo "========================================"

# Validate config file
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found at $CONFIG_FILE"
    exit 1
fi

if [ -n "$TARGET_WEBSITE" ]; then
    # Process specific website
    echo "Target: $TARGET_WEBSITE (from cron job)"
    
    WEBSITE_JSON=$(jq -c ".websites[] | select(.name == \"$TARGET_WEBSITE\" and .enabled == true)" "$CONFIG_FILE")
    
    if [ -z "$WEBSITE_JSON" ]; then
        echo "ERROR: Website '$TARGET_WEBSITE' not found or not enabled in config"
        exit 1
    fi
    
    process_website "$WEBSITE_JSON"
else
    # Process all enabled websites (backward compatibility)
    echo "Target: All enabled websites"
    
    PROCESSED=0
    while IFS= read -r website_json; do
        if [ -n "$website_json" ]; then
            process_website "$website_json"
            PROCESSED=$((PROCESSED + 1))
        fi
    done < <(jq -c '.websites[] | select(.enabled == true)' "$CONFIG_FILE")
    
    echo ""
    echo "========================================"
    echo "Summary: Processed $PROCESSED website(s)"
    echo "========================================"
fi

echo ""
echo "All operations completed successfully!"
echo "Time: $(date)"
