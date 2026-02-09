# Cron-based Docs MCP Server

A Docker image that wraps [arabold/docs-mcp-server](https://github.com/arabold/docs-mcp-server) with automated cron-based documentation scraping and refreshing.

## What It Does

Automatically scrapes and indexes documentation websites on a schedule, making them searchable via MCP (Model Context Protocol).

## Configuration

Create a `config.json` file:

```json
{
  "global-settings": {
    "cronSchedule": "0 2 * * *",
    "telemetryEnabled": false,
    "scraper": {
      "scope": "hostname"
    }
  },
  "websites": [
    {
      "name": "my-docs",
      "url": "https://docs.example.com",
      "description": "My documentation",
      "enabled": true
    }
  ]
}
```

**Cron schedule examples:**
- `0 2 * * *` - Daily at 2:00 AM (default)
- `0 */6 * * *` - Every 6 hours
- `0 0 * * 0` - Weekly on Sunday

See [config.json.example](config.json.example) for all available options.

### Indexing PDF Documents

The scraper automatically indexes PDF files linked from HTML pages. For PDFs to be discovered and crawled, set `scope: "hostname"` in global scraper settings:

```json
{
  "global-settings": {
    "cronSchedule": "0 2 * * *",
    "telemetryEnabled": false,
    "scraper": {
      "maxDepth": 2,
      "scope": "hostname"
    }
  }
}
```

**Why this is needed:** The default scope is `"subpages"` which only follows links under the starting URL path. PDFs are often in different paths (like `/documents/`), so `"hostname"` allows following all links on the same domain.

**Note:** Large PDFs may be skipped if they exceed the document size limit. Set `DOCS_MCP_SCRAPER_DOCUMENT_MAX_SIZE=52428800` (50MB) for example, or another size in your environment if needed.

## Deployment

1. Create your `config.json` file
2. Set your OpenAI API key: `export OPENAI_API_KEY="your-key-here"`
3. Deploy with Docker Compose:

```bash
docker compose up -d
```

**docker-compose.yml:**
```yaml
services:
  cron-docs-mcp:
    image: ghcr.io/leonine-studios/docs-mcp-cron:latest
    container_name: cron-docs-mcp
    volumes:
      - ./docs-mcp-data:/data
      - ./config.json:/config.json:ro
      - ./logs:/var/log
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - DOCS_MCP_TELEMETRY=false
      - DOCS_MCP_SCRAPER_DOCUMENT_MAX_SIZE=${DOCS_MCP_SCRAPER_DOCUMENT_MAX_SIZE}
    restart: unless-stopped
```

## Initial Setup

After deploying, trigger the initial scraping:

```bash
docker exec cron-docs-mcp scrape-or-refresh.sh
```

This populates all enabled libraries. You can see the logs as it runs. Subsequent runs will be faster as it only refreshes changes instead of re-scraping everything.

**Alternative:** Wait for the scheduled cron (default: 2 AM daily) to run automatically.

## Environment Variables

- `OPENAI_API_KEY` - Your OpenAI API key for embeddings
- `DOCS_MCP_TELEMETRY` - Enable/disable telemetry (default: `true`)
- `DOCS_MCP_SCRAPER_DOCUMENT_MAX_SIZE` - (Optional) Maximum size in bytes for PDF/Office documents (default: 10485760 = 10MB)
  - To allow larger documents (e.g., 50MB), set: `export DOCS_MCP_SCRAPER_DOCUMENT_MAX_SIZE=52428800`

You can set environment variables in your shell or create a `.env` file:

```bash
export OPENAI_API_KEY="your-key-here"
# Optional: Increase document size limit to 50MB
export DOCS_MCP_SCRAPER_DOCUMENT_MAX_SIZE=52428800
```

## Library Synchronization

The system automatically keeps libraries in sync with your `config.json` in **real-time**:

- **Real-Time Cleanup**: When you edit `config.json` and remove a website, its scraped library is **automatically deleted within seconds**
- **File Watcher**: A background process monitors `config.json` for changes and triggers sync immediately
- **Startup Sync**: An initial sync runs when the container starts to catch any changes while it was down
- **No Orphaned Data**: Only websites currently in your configuration will have libraries stored  
- **Manual Sync**: You can also manually trigger sync anytime with: `docker exec cron-docs-mcp sync-libraries.sh`

### How It Works:

1. You edit `config.json` and remove a website
2. The file watcher detects the change within seconds
3. It validates the JSON syntax
4. If valid, it automatically runs the sync script
5. Orphaned libraries are deleted immediately

You can monitor the watcher logs:
```bash
docker exec cron-docs-mcp tail -f /var/log/docs-mcp-config-watcher.log
```

## Testing

```bash
# Trigger initial scrape (also runs sync to remove orphaned libraries)
docker exec cron-docs-mcp scrape-or-refresh.sh

# Manually sync libraries with config (remove orphaned libraries)
docker exec cron-docs-mcp sync-libraries.sh

# List indexed libraries
docker exec cron-docs-mcp node /app/dist/index.js list

# View container logs
docker logs -f cron-docs-mcp

# View cron job logs (from host)
tail -f logs/docs-mcp-refresh.log

# View config watcher logs (monitors for config.json changes)
docker exec cron-docs-mcp tail -f /var/log/docs-mcp-config-watcher.log

# Check cron jobs
docker exec cron-docs-mcp crontab -l
```

## Credits

Built on top of [arabold/docs-mcp-server](https://github.com/arabold/docs-mcp-server) - a fantastic MCP server for documentation indexing and search.
