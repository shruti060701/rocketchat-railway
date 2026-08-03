# Rocket.Chat Template Composer Checklist

## Services

- **rocketchat-railway** (this repo, root directory `rocketchat/`, `rocketchat/rocket.chat:8.6.1`)
- **mongodb-railway** (this repo, root directory `mongodb/`, custom `mongo:8.0` + replica-set init wrapper)

Real live service names and any renamed defaults: TBD after GitHub connect + first deploy.

## Healthcheck (set explicitly in the composer, railway.toml does not carry through automatically)

- **Service:** `rocketchat-railway` (the app service, not MongoDB)
- **Path:** `/api/v1/info`
- **Timeout:** `300` seconds
- **`RAILWAY_HEALTHCHECK_PATH` variable:** set to `/api/v1/info` with description "The endpoint Railway uses to verify the service is healthy."
- MongoDB service has no HTTP healthcheck (raw TCP service, matches how native Postgres/Redis plugins also have no HTTP healthcheck).
- To verify live: confirm real `200 OK` from `/api/v1/info`, and separately confirm real replica-set initiation in MongoDB's boot logs (`Initiating ReplSet rs0` followed by success), don't rely on the app healthcheck alone as proof the replica set actually works, since Rocket.Chat can boot and respond to `/api/v1/info` even without a working replica set.

## Deploy Verification

- [ ] MongoDB boots clean, logs show real replica-set initiation (`Initiating ReplSet rs0...`) not just a clean process start
- [ ] Confirm replica set status directly (`rs.status().ok` returns `1`), not inferred from app-level behavior
- [ ] Rocket.Chat boots clean, connects to MongoDB successfully (check logs for a connection error, common failure mode if `MONGO_URL`'s `replicaSet=rs0` query param or `MONGODB_ADVERTISED_HOSTNAME` is wrong)
- [ ] Domain generated, `/api/v1/info` returns real `200 OK`
- [ ] Open the domain, confirm the real admin SETUP wizard appears (not a login form), complete it with a real admin account
- [ ] Real-time test: open two browser sessions (or two curl-based WebSocket checks), send a message in one, confirm it appears in the other without a manual refresh — this is the one thing that silently breaks if the replica set isn't actually working, so a passing healthcheck alone does NOT prove this works
- [ ] Redeploy MongoDB once, confirm the replica-set init logic is idempotent (doesn't error on an already-initiated replica set) and data survives

## `rocketchat-railway` App Variables

| Variable | Value | Mark Optional | Description |
|----------|-------|----------------|--------------|
| `ROOT_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | No | Public URL this instance is reachable at, used for links generated in notifications and invites. |
| `DEPLOY_METHOD` | `docker` | Yes | Tells Rocket.Chat it's running via Docker, matches the official reference compose. |
| `MONGO_URL` | `mongodb://${{mongodb-railway.RAILWAY_PRIVATE_DOMAIN}}:27017/rocketchat?replicaSet=rs0` | No | MongoDB connection string, must include the replica set name or Rocket.Chat won't connect correctly. |

## `mongodb-railway` App Variables

| Variable | Value | Mark Optional | Description |
|----------|-------|----------------|--------------|
| `MONGODB_ADVERTISED_HOSTNAME` | `${{RAILWAY_PRIVATE_DOMAIN}}` | No | Hostname the replica set member is registered under. Must be reachable from the separate Rocket.Chat container, not `localhost`, or Rocket.Chat's driver can't resolve the replica set member address. |

## Platform-Injected `RAILWAY_*` Variables

Write one explicit row per variable actually shown on each live service's Variables tab after first deploy, not a summarizing paragraph. Standard treatment: mark optional = Yes, leave value empty, description "Railway platform setting, not specific to this template." **Always include `RAILWAY_DEPLOYMENT_DRAINING_SECONDS`** on every service that shows it, this has been missed before (Appsmith template) — don't repeat that gap.

## Volume

- **mongodb-railway mount path:** `/data/db`
- **Purpose:** Holds all Rocket.Chat data (messages, users, uploaded files via GridFS, and the replica set's own oplog). Without this volume, every redeploy wipes everything, including the replica set configuration itself.
- **rocketchat-railway needs no volume** — stateless, all data lives in MongoDB.

## Known Findings To Verify Live (not assumed, confirm after deploy)

- **Replica set init is a custom wrapper, not a Railway-native feature.** Confirm the exact idempotency check (`rs.status().ok`) works correctly across a real redeploy, not just a first boot, before trusting this template long-term.
- **`MONGO_URL` cross-service reference syntax**: confirm `${{mongodb-railway.RAILWAY_PRIVATE_DOMAIN}}` resolves correctly once the real service name is known post-connect (service name in the reference syntax must exactly match the live Railway service name, which may differ from `mongodb-railway` if Shruti names it differently when connecting the GitHub repo).
- **Rocket.Chat's own internal port**: confirmed via its own Dockerfile documentation to be 3000, but per this project's now-repeated PORT findings (pgAdmin, Appsmith, Flowise all differed), verify live via logs and curl rather than assuming.

## Known Troubleshooting

- **If Rocket.Chat can't connect to MongoDB**, check `MONGO_URL` includes `?replicaSet=rs0` exactly, and confirm the MongoDB service's replica set actually initiated (check its logs), not just that the container is running.
- **If real-time updates don't work but everything else seems fine**, this is the classic symptom of a MongoDB replica set that never actually initiated. Check MongoDB's logs for the initiation sequence, and confirm `rs.status().ok` returns `1`.
- **If the MongoDB service crashes on boot after a redeploy**, check whether the replica-set init logic is correctly skipping re-initiation (`STATUS != "1"` check in the wrapper script) rather than erroring on an already-initiated replica set.

## Post-Deploy Steps

1. Confirm the MongoDB replica set actually initiated (real proof, not assumed) via logs and `rs.status()`.
2. Complete the real admin setup wizard.
3. Run the real-time two-session test (send a message in one session, confirm it appears live in the other) — this is the single most important functional test for this template, since it's the one thing that fails silently if the setup is wrong.
4. Redeploy MongoDB once and confirm everything survives.

Status: Rocket.Chat template built and documented, not yet pushed to GitHub or deployed. Composer checklist will be finalized with real service names, confirmed PORT/replica-set behavior, and live `railway variables --json` output immediately after deployment and verification, per this project's standing rule.
