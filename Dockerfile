FROM ghcr.io/arabold/docs-mcp-server:latest

# Install jq and cron
RUN apt-get update && \
    apt-get install -y jq cron && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy scripts into the container
COPY scripts/scrape-or-refresh.sh /usr/local/bin/scrape-or-refresh.sh
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/scrape-or-refresh.sh /usr/local/bin/entrypoint.sh

# Create log file for cron jobs (cron schedule configured at runtime)
RUN touch /var/log/docs-mcp-refresh.log

# Expect /config.json to be mounted at runtime
# The entrypoint will validate and configure cron based on the config

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mcp", "--read-only", "--protocol", "http", "--port", "6280"]
