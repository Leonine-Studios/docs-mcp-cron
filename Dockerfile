FROM ghcr.io/arabold/docs-mcp-server:latest

# Install dependencies and set up log files in a single layer
RUN apt-get update && \
    apt-get install -y jq cron inotify-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    touch /var/log/docs-mcp-refresh.log /var/log/docs-mcp-config-watcher.log


COPY scripts/*.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Expect /config.json to be mounted at runtime
# The entrypoint will validate and configure cron based on the config

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mcp", "--read-only", "--protocol", "http", "--port", "6280"]
