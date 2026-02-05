#!/bin/bash
set -e

CONFIG_FILE="/config.json"

echo "Starting config.json file watcher..."
echo "Monitoring: $CONFIG_FILE"
echo "Any changes will trigger library synchronization"
echo ""

# Initial sync on startup
echo "Running initial sync..."
/usr/local/bin/sync-libraries.sh

# Watch for changes to config.json
while true; do
    # Use inotifywait to monitor for file modifications
    # -e modify: Watch for file content changes
    # -e moved_to: Watch for file being moved/renamed into place (common with editors)
    # -q: Quiet mode
    inotifywait -q -e modify -e moved_to "$CONFIG_FILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "========================================" 
        echo "Config file changed detected!"
        echo "Time: $(date)"
        echo "========================================" 
        
        # Wait a moment for the file write to complete
        sleep 2
        
        # Validate the JSON before syncing
        if jq empty "$CONFIG_FILE" 2>/dev/null; then
            echo "✓ Config file is valid JSON"
            
            # Trigger sync
            /usr/local/bin/sync-libraries.sh
        else
            echo "⚠ Config file contains invalid JSON - skipping sync"
            echo "Please fix the JSON syntax and save again"
        fi
        
        echo ""
    fi
done
