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
    "telemetryEnabled": false
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
      - DOCS_MCP_SCRAPER_DOCUMENT_MAX_SIZE=52428800  # 50MB max document size
    restart: unless-stopped
```

## Environment Variables

- `OPENAI_API_KEY` - Your OpenAI API key for embeddings
- `DOCS_MCP_TELEMETRY` - Enable/disable telemetry (default: `true`)
- `DOCS_MCP_SCRAPER_DOCUMENT_MAX_SIZE` - Maximum size in bytes for PDF/Office documents (default: 10485760 = 10MB)

For additional environment variables, see the [upstream configuration documentation](https://github.com/arabold/docs-mcp-server/blob/main/docs/setup/configuration.md).

## Testing

```bash
# Trigger initial scrape
docker exec cron-docs-mcp scrape-or-refresh.sh

# List indexed libraries
docker exec cron-docs-mcp node /app/dist/index.js list

# View container logs
docker logs -f cron-docs-mcp

# View cron job logs (from host)
tail -f logs/docs-mcp-refresh.log

# Check cron jobs
docker exec cron-docs-mcp crontab -l
```

## Credits

Built on top of [arabold/docs-mcp-server](https://github.com/arabold/docs-mcp-server) - a fantastic MCP server for documentation indexing and search.
