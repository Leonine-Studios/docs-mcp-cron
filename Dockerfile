FROM ghcr.io/arabold/docs-mcp-server:latest

# v3.3.0 switches to the unprivileged node user. Cron, crontab, and apt need root.
USER root

# trixie-slim has no bash. The scripts use a bash shebang.
# --no-install-recommends avoids pulling an extra mail server in with cron.
RUN apt-get update && \
    apt-get install -y --no-install-recommends bash jq cron inotify-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    touch /var/log/docs-mcp-refresh.log /var/log/docs-mcp-config-watcher.log


COPY scripts/*.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Expect /config.json to be mounted at runtime
# The entrypoint will validate and configure cron based on the config

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mcp", "--read-only", "--protocol", "http", "--port", "6280"]
