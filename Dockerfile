FROM ghcr.io/arabold/docs-mcp-server:latest

# Install jq, cron, and inotify-tools (for file watching)
RUN apt-get update && \
    apt-get install -y jq cron inotify-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy scripts into the container
COPY scripts/scrape-or-refresh.sh /usr/local/bin/scrape-or-refresh.sh
COPY scripts/sync-libraries.sh /usr/local/bin/sync-libraries.sh
COPY scripts/watch-config.sh /usr/local/bin/watch-config.sh
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/scrape-or-refresh.sh /usr/local/bin/sync-libraries.sh /usr/local/bin/watch-config.sh /usr/local/bin/entrypoint.sh

# Create log files for cron jobs and config watcher
RUN touch /var/log/docs-mcp-refresh.log /var/log/docs-mcp-config-watcher.log

# Expect /config.json to be mounted at runtime
# The entrypoint will validate and configure cron based on the config

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mcp", "--read-only", "--protocol", "http", "--port", "6280"]
