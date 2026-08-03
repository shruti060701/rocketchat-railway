FROM mongo:8.0

# Pinned to exactly the MongoDB version Rocket.Chat 8.6.1 requires, confirmed
# via Rocket.Chat's own GitHub release notes ("Engine versions: MongoDB: 8.0").

COPY docker-entrypoint-wrapper.sh /docker-entrypoint-wrapper.sh
RUN chmod +x /docker-entrypoint-wrapper.sh

# Persistence is handled via a Railway Volume (attached separately with
# `railway volume add --mount-path /data/db`), not Docker's VOLUME
# instruction - Railway's builder rejects that outright.

ENTRYPOINT ["/docker-entrypoint-wrapper.sh"]
