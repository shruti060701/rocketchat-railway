# Deploy and Host Rocket.Chat-self-hosted on Railway

Rocket.Chat is the open-source team communication platform that replaces Slack and Microsoft Teams. Real-time messaging, threads, video calls, and omnichannel customer support, all running on infrastructure you control instead of a per-seat SaaS subscription.

## About Hosting Rocket.Chat-self-hosted

Team chat platforms accumulate an enormous amount of sensitive material over time. Not just casual conversation, but decisions, credentials shared in a pinch, customer complaints, sometimes contract negotiations happening in a DM thread. Every bit of that lives somewhere, and with a SaaS platform, that somewhere is a vendor's infrastructure, not yours.

Slack's Pro plan runs $7.25 per user per month, before Enterprise Grid pricing for larger orgs. A 20-person team on Slack Pro clears $145 a month, every month, scaling directly with headcount. Rocket.Chat's core is open-source, no per-seat fee when you self-host it. The same 20-person team on self-hosted Rocket.Chat pays a flat Railway cost regardless of whether you're at 20 people or 200.

Here's the one technical detail worth understanding before deploying this template: it requires MongoDB configured as a replica set, not just a plain instance. Not a performance optimization, a hard requirement, confirmed directly in Rocket.Chat's own official `rocketchat-compose` reference repository. Real-time features (live message updates, typing indicators, presence) depend on MongoDB Change Streams, which only function on a replica set. Point Rocket.Chat at a plain non-replica-set MongoDB and it starts up fine, logs in fine, but real-time updates silently don't work, you'd have to refresh to see new messages. Railway has no native MongoDB plugin with replica-set support, so this template ships a custom MongoDB service that configures and initiates the replica set automatically on first boot.

## Common Use Cases

- **Internal team chat**: Channels, threads, and direct messages for engineering, ops, or company-wide communication.
- **Customer support omnichannel**: Route WhatsApp, SMS, and email conversations into one agent-facing inbox, no separate tool per channel.
- **Video and voice calls**: Built-in calling, no separate video conferencing subscription needed.
- **Compliance-sensitive communication**: Keep conversation data on infrastructure you control, relevant for regulated industries or internal policy requirements.
- **Community and open-source project chat**: Public channels for a community, replacing a paid Discord or Slack workspace as the community scales.
- **Replacing a fragmented internal tool stack**: One platform for chat, calls, and customer messaging instead of three separate subscriptions.

## Dependencies for Rocket.Chat-self-hosted Hosting

- MongoDB, configured specifically as a replica set, this is non-negotiable for real-time features to work.
- Persistent storage for MongoDB's own data (messages, users, and uploaded files via GridFS by default).

### Deployment Dependencies

Reference: [Rocket.Chat GitHub Repository](https://github.com/RocketChat/Rocket.Chat), [Official rocketchat-compose Reference](https://github.com/RocketChat/rocketchat-compose), [Rocket.Chat Documentation](https://docs.rocket.chat).

### Implementation Details

This template runs `rocketchat/rocket.chat:8.6.1` and `mongo:8.0`, both pinned. `8.0` is the exact MongoDB version Rocket.Chat 8.6.1 requires, confirmed in Rocket.Chat's own GitHub release notes under "Engine versions." The MongoDB service's Dockerfile wraps the base image's own entrypoint with a script that starts `mongod --replSet rs0 --bind_ip_all`, waits for it to respond, then runs `rs.initiate()` exactly once, checked idempotently so it's safe across every future redeploy. The replica set member is registered under this service's real Railway private-network hostname, not `localhost`, since Rocket.Chat connects from a separate container and needs an address it can actually resolve. Rocket.Chat itself is stateless, no volume needed there, every bit of persistent state lives in MongoDB.

## How Rocket.Chat Compares to the Alternatives

**Vs. Slack**: Slack is polished and has the largest app ecosystem of any team chat tool. But it's SaaS-only, your data lives on Slack's infrastructure, and pricing scales per seat indefinitely. Rocket.Chat trades some of Slack's third-party integration breadth for full data ownership and a genuinely free core.

**Vs. Mattermost**: Mattermost is Rocket.Chat's closest open-source competitor, and it's a solid choice too. The meaningful difference is omnichannel, Rocket.Chat ships WhatsApp, SMS, and email routing in its free tier, while Mattermost's free Team Edition focuses more narrowly on internal chat and caps out at 250 users.

**Vs. Microsoft Teams**: Teams is deeply integrated with Microsoft 365, which is either a major advantage or a major lock-in cost depending on your stack. Rocket.Chat's open REST API and webhook system make custom integrations more straightforward, without needing Microsoft's enterprise licensing tier to unlock the APIs you need.

## Getting Started

First boot takes a couple of minutes, MongoDB's replica set has to initialize before Rocket.Chat can connect to it successfully. Watch the MongoDB service's logs for "Initiating ReplSet rs0" followed by a success message before assuming something's wrong if the app doesn't respond instantly.

Once your Railway domain loads, you'll land on Rocket.Chat's admin setup wizard, not a login form. Walk through it to create your organization and admin account, this account becomes your workspace owner.

From the admin panel, create your first few channels before inviting your whole team, a `#general` and a `#random` at minimum, matching how most teams actually structure day-to-day chat. If you're planning to use Omnichannel for customer support, that's configured separately under Administration, connecting a WhatsApp Business API, SMS provider, or email inbox to route into agent queues.

Test real-time updates directly rather than assuming they work: open two browser tabs (or have a teammate join), send a message in one, and confirm it appears instantly in the other without a refresh. That's the actual proof the MongoDB replica set is correctly configured, since that's precisely the feature that breaks silently without one.

One thing worth testing deliberately: redeploy the MongoDB service once, early, before you've built up conversation history you'd be upset to lose, and confirm the replica set reinitializes correctly and your data survives. That's real proof the persistence and replica-set setup are both wired up right, not just working because nothing's restarted yet.

## Why Deploy Rocket.Chat-self-hosted on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Rocket.Chat-self-hosted on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

## Frequently Asked Questions

### Why does this template need a custom MongoDB service instead of a simple database plugin?
Rocket.Chat requires MongoDB configured specifically as a replica set for its real-time features (live updates, typing indicators, presence) to work at all, confirmed directly in Rocket.Chat's own official reference deployment. Railway has no native MongoDB plugin with replica-set support, so this template includes a custom MongoDB service that handles the replica-set setup automatically.

### What happens if the replica set isn't configured correctly?
Rocket.Chat still starts and you can still log in, but real-time updates silently stop working, you'd have to manually refresh to see new messages. It's a subtle failure mode rather than an obvious crash, which is exactly why this template handles the setup automatically rather than leaving it to a deployer to configure by hand.

### Will my messages and files survive a redeploy?
Yes, all Rocket.Chat data lives in MongoDB on a persistent volume, independent of the app service's own redeploys. The replica-set initialization is idempotent too, so a MongoDB redeploy won't break anything that's already configured.

### Do I need to bring my own file storage for uploads?
Not by default, Rocket.Chat stores uploaded files in MongoDB via GridFS out of the box. For larger deployments with heavy file traffic, Rocket.Chat also supports S3-compatible storage as a separate configuration option.

### Can I use Rocket.Chat for customer support, not just internal chat?
Yes, the Omnichannel module routes WhatsApp, SMS, email, and live chat widget conversations into one agent-facing inbox, configurable from the admin panel after your workspace is set up.

### Is Rocket.Chat's video calling included, or does it need a separate service?
Built-in calling is included in the open-source core, no separate video conferencing subscription required for basic one-on-one and small group calls.

### Can I run this for a large team, or is it meant for small setups?
Rocket.Chat scales well beyond small teams, real deployments run into the thousands of users. What scales with team size is mostly MongoDB's resource needs, the app service itself is comparatively lightweight since it's stateless.

### How does admin access work if multiple people need admin rights?
The first person through setup becomes the owner, but Rocket.Chat supports adding more admins afterward through User Management, with granular role-based permissions beyond just "admin or not."

### Does this template expose MongoDB publicly?
No, MongoDB stays on Railway's private network, reachable only from the Rocket.Chat service in the same project, not the public internet.
