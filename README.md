# Rocket.Chat: Open-Source Team Chat

Deploy Rocket.Chat, the open-source real-time team chat platform, a Slack and Microsoft Teams alternative, on Railway with one click. Messaging, threads, video calls, and omnichannel customer support.

## Deploy on Railway

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/new/template)

## Features

- **Real-time messaging**: Channels, threads, and direct messages with live updates.
- **Video and voice calls**: Built-in calling, no separate conferencing tool needed.
- **Omnichannel support**: Route WhatsApp, SMS, and email into one agent inbox.
- **REST API and webhooks**: Build custom integrations without enterprise licensing overhead.
- **Fully open-source**: No per-seat fee, self-hosted with full data ownership.

## Architecture

This template deploys two services from this repo:
- **`rocketchat/`**: the Rocket.Chat app itself (`rocketchat/rocket.chat:8.6.1`).
- **`mongodb/`**: a custom MongoDB service (`mongo:8.0`) configured as a single-node replica set, required for Rocket.Chat's real-time features. Railway has no native MongoDB plugin with replica-set support, so this is a custom Dockerfile with a wrapper entrypoint that initiates the replica set automatically on first boot.

When connecting the GitHub repo in Railway, set each service's **root directory** to the matching subfolder (`rocketchat` or `mongodb`).

## How to Use

1. Click the Deploy on Railway button above.
2. Railway provisions both services, MongoDB's replica set initializes automatically on first boot.
3. Open your Railway domain, you'll land on the admin setup wizard, not a login form.
4. Complete setup to create your organization and admin account.

## Notes

- **MongoDB replica set is not optional.** Without it, Rocket.Chat starts and logs in fine, but real-time updates (live messages, typing indicators, presence) silently stop working. This template handles it automatically.
- **A persistent volume at `/data/db` on the MongoDB service is required** for messages, users, and uploaded files (stored via GridFS by default) to survive redeploys.
- **Rocket.Chat itself is stateless** and needs no volume, all state lives in MongoDB.
- **`MONGODB_ADVERTISED_HOSTNAME` must be set to MongoDB's own `RAILWAY_PRIVATE_DOMAIN`**, not `localhost`, since the replica set member address needs to be reachable from the separate Rocket.Chat container.

## Self-Hosting on Other Platforms

Use the official reference deployment:
```bash
git clone https://github.com/RocketChat/rocketchat-compose
cd rocketchat-compose
cp .env.example .env
docker compose -f compose.database.yml -f compose.yml -f compose.traefik.yml up -d
```

## License

Rocket.Chat's core is released under the MIT license (Community Edition), free to self-host with no seat limits.

## Support

- **GitHub**: https://github.com/RocketChat/Rocket.Chat
- **Docs**: https://docs.rocket.chat
- **Issues**: https://github.com/RocketChat/Rocket.Chat/issues
