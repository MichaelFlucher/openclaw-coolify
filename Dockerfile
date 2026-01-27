FROM ghcr.io/clawdbot/clawdbot:main

USER root

# Add bootstrap script
COPY scripts/bootstrap.sh /app/scripts/bootstrap.sh
RUN chmod +x /app/scripts/bootstrap.sh

# Back to non-root (important for security + review)
USER node