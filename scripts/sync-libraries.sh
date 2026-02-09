#!/bin/bash
set -e

# Set PATH for cron environment
export PATH=/usr/local/bin:/usr/bin:/bin:$PATH

CONFIG_FILE="/config.json"

echo ""
echo "========================================"
echo "Syncing Libraries with Config"
echo "Time: $(date)"
echo "========================================"

# Validate config file
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found at $CONFIG_FILE"
    exit 1
fi

# Get list of all website names from config (both enabled and disabled)
# Convert to lowercase for case-insensitive comparison (library names are stored lowercase)
CONFIG_WEBSITES=$(jq -r '.websites[].name' "$CONFIG_FILE" | tr '[:upper:]' '[:lower:]' | sort)

# Get list of existing libraries
echo "Fetching existing libraries..."
EXISTING_LIBS_JSON=$(node /app/dist/index.js list 2>/dev/null || echo "[]")

# Parse JSON to extract library names
EXISTING_LIBS=$(echo "$EXISTING_LIBS_JSON" | jq -r '.[].name' 2>/dev/null || echo "")

if [ -z "$EXISTING_LIBS" ]; then
    echo "No existing libraries found."
    exit 0
fi

# Convert to sorted list
EXISTING_LIBS_SORTED=$(echo "$EXISTING_LIBS" | sort)

echo ""
echo "Websites in config:"
echo "$CONFIG_WEBSITES"
echo ""
echo "Existing libraries:"
echo "$EXISTING_LIBS_SORTED"
echo ""

# Find libraries that are not in config and should be deleted
DELETED_COUNT=0
while IFS= read -r lib_name; do
    if [ -n "$lib_name" ]; then
        # Check if this library exists in config
        if ! echo "$CONFIG_WEBSITES" | grep -q "^${lib_name}$"; then
            echo "🗑️  Deleting orphaned library: $lib_name"
            
            # Remove the library (this only removes documents/pages)
            if node /app/dist/index.js remove "$lib_name" 2>/dev/null; then
                # Also remove version and library metadata from database
                node -e "
                const Database = require('better-sqlite3');
                const db = new Database('/data/documents.db');
                try {
                    // Delete version record for this library
                    const deleteVersionStmt = db.prepare(\`
                        DELETE FROM versions 
                        WHERE library_id = (SELECT id FROM libraries WHERE name = ?)
                    \`);
                    deleteVersionStmt.run('$lib_name');
                    
                    // Delete library record if no versions remain
                    const deleteLibraryStmt = db.prepare(\`
                        DELETE FROM libraries 
                        WHERE name = ? 
                        AND NOT EXISTS (
                            SELECT 1 FROM versions WHERE library_id = libraries.id
                        )
                    \`);
                    deleteLibraryStmt.run('$lib_name');
                    
                    db.close();
                } catch (err) {
                    console.error('DB cleanup error:', err.message);
                    db.close();
                }
                " 2>/dev/null
                
                echo "   ✓ Successfully deleted: $lib_name"
                DELETED_COUNT=$((DELETED_COUNT + 1))
            else
                echo "   ✗ Failed to delete: $lib_name"
            fi
        fi
    fi
done <<< "$EXISTING_LIBS_SORTED"

echo ""
echo "========================================"
if [ $DELETED_COUNT -eq 0 ]; then
    echo "✓ No orphaned libraries found"
else
    echo "✓ Deleted $DELETED_COUNT orphaned library(ies)"
fi
echo "========================================"
echo ""
