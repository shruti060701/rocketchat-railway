#!/bin/bash
set -e

# Rocket.Chat requires MongoDB to run as a replica set (it uses Change Streams
# for real-time features), confirmed directly in Rocket.Chat's own official
# rocketchat-compose repo (RocketChat/rocketchat-compose, compose.database.yml).
# A plain `mongo` container with no replica set configured will let Rocket.Chat
# connect, but every real-time feature silently breaks. This wrapper starts
# mongod with a replica set enabled, then initiates that replica set on first
# boot only (idempotent - safe to run again on every redeploy).
#
# The replica set member must be registered under a hostname OTHER services
# (Rocket.Chat) can actually resolve, not "localhost" - localhost only works
# for clients inside this same container. MONGODB_ADVERTISED_HOSTNAME is set
# to this service's Railway private-network domain for exactly that reason.

: "${MONGODB_ADVERTISED_HOSTNAME:?MONGODB_ADVERTISED_HOSTNAME must be set to this service's own RAILWAY_PRIVATE_DOMAIN}"

docker-entrypoint.sh mongod --replSet rs0 --bind_ip_all &
MONGO_PID=$!

echo "=====> Waiting for MongoDB to be ready..."
until mongosh --eval "db.adminCommand('ping')" >/dev/null 2>&1; do
  sleep 1
done

STATUS=$(mongosh --quiet --eval "try { rs.status().ok } catch(e) { print(0) }")
if [ "$STATUS" != "1" ]; then
  echo "=====> Initiating replica set rs0 with member $MONGODB_ADVERTISED_HOSTNAME:27017..."
  mongosh --eval "rs.initiate({_id: 'rs0', members: [{ _id: 0, host: '$MONGODB_ADVERTISED_HOSTNAME:27017' }]})"
else
  echo "=====> Replica set rs0 already initiated, skipping."
fi

wait "$MONGO_PID"
