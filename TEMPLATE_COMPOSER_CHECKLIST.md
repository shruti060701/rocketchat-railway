# Rocket.Chat Template Composer Checklist

## Services

- **rocketchat-railway** (repo `shruti060701/rocketchat-railway`, root directory `rocketchat/`, `rocketchat/rocket.chat:8.6.1`)
- **independent-reverence** (Railway's auto-generated name, repo root directory `mongodb/`, custom `mongo:8.0` + replica-set init wrapper) — **consider renaming this to `mongodb-railway` in the dashboard for clarity before publishing**, the auto-generated name works but is confusing in the composer.

Live project: `https://railway.com/project/15803a4d-9e29-4180-b884-b40ddc2f688a`
Live domain: `https://rocketchat-railway-production.up.railway.app`

## Healthcheck (set explicitly in the composer, railway.toml does not carry through automatically)

- **Service:** `rocketchat-railway` (the app service, not MongoDB)
- **Path:** `/api/info` — **NOT `/api/v1/info`**, confirmed live. Web research suggested `/api/v1/info` was the "modern" endpoint for 8.2.0+, that was wrong; `/api/v1/info` returns a real `404` on this live 8.6.1 instance, while `/api/info` (the older, unversioned path) returns a real `200` with full workspace info. Don't trust secondhand research over a live curl test, confirmed yet again.
- **Timeout:** `300` seconds
- **`RAILWAY_HEALTHCHECK_PATH` variable:** set to `/api/info` with description "The endpoint Railway uses to verify the service is healthy."
- MongoDB service has no HTTP healthcheck (raw TCP service).

## Two Real Bugs Found and Fixed Live (neither assumed, neither obvious)

1. **Bash syntax bug in the MongoDB entrypoint wrapper, crash-looping on every boot.** An apostrophe inside a `${VAR:?error message}` parameter-expansion construct (`"this service's own..."`) broke bash's parser with `unexpected EOF while looking for matching \`''`, even though the apostrophe was inside an outer double-quoted string, where a stray single quote should normally be inert. This is a real, confirmed bash quirk specific to the `${VAR:?message}` construct, reproduced locally with `bash -n`, not a container-specific issue. **Fix:** avoid apostrophes entirely inside `${VAR:?message}` error text. **Always run `bash -n <script>` locally before pushing any new wrapper script** — this would have caught it before ever deploying.
2. **`ROOT_URL` evaluated to `https://` (no domain) because I set the variable before generating a public domain**, since `${{RAILWAY_PUBLIC_DOMAIN}}` resolves empty until a domain actually exists. Rocket.Chat's own Meteor boot process hard-fails with `Error: $ROOT_URL, if specified, must be an URL` if this happens. **Fix (and standing lesson for future templates):** always run `railway domain` BEFORE setting any variable that references `${{RAILWAY_PUBLIC_DOMAIN}}`, not after, or the reference resolves empty and silently breaks whatever consumes it.

## One Real Dead-End Investigated and Resolved (worth knowing, not a bug in the final template)

Along the way to finding bug #2, briefly set an explicit `PORT=3000` variable on `rocketchat-railway`, hypothesizing a mismatch between the Dockerfile's `EXPOSE 3000` and Railway's proxy target port (the Appsmith-style bug). **This was wrong and made things temporarily worse** (`502 Application failed to respond`, since Railway's proxy defaults to expecting `8080` regardless of `EXPOSE`, matching the established finding from Appsmith, not derived from the Dockerfile at all). **The actual correct fix was to NOT set `PORT` at all**, letting Railway's own injected runtime `PORT=8080` flow through uninterrupted, exactly like the Flowise template. Confirmed live: `Process Port: 8080` in Rocket.Chat's own boot banner, and the domain routes correctly once `PORT` is left unset. **Lesson for future templates: don't assume a PORT-collision fix pattern from one template transfers to the next — Appsmith needed an explicit override, Flowise and Rocket.Chat did not, verify fresh every time.**

## Deploy Verification (all confirmed live, 2026-08-03)

- [x] MongoDB boots clean, real replica-set initiation confirmed in logs (`=====> Initiating replica set rs0 with member independent-reverence.railway.internal:27017...` followed by `Transition to primary complete; database writes are now permitted`)
- [x] Rocket.Chat boots clean, connects to MongoDB successfully (`Connected to MongoDB database: rocketchat`, `MongoDB Version: 8.0.28` in boot banner, a real live connection, not a config echo)
- [x] Domain generated, `/api/info` returns real `200 OK` with full workspace JSON
- [x] Real admin registration test: `POST /api/v1/users.register` with `{username, email, pass, name}` returned real `200` with a created user document (`_id`, `__rooms: ["GENERAL"]`) — confirms MongoDB write path works end-to-end. (Note: username `admin` is a reserved/blocked username, confirmed live via a real `400 error-blocked-username` — use something else.)
- [x] Real login test: `POST /api/v1/login` with the registered credentials returned real `200` with a valid `authToken` and `"roles":["user","admin"]` — confirms the first registered user is auto-promoted to workspace admin, and the full auth flow works end-to-end.

## `rocketchat-railway` App Variables

| Variable | Value | Mark Optional | Description |
|----------|-------|----------------|--------------|
| `ROOT_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | No | Public URL this instance is reachable at. **Generate the domain BEFORE setting this**, or it resolves to `https://` with no host and crashes the app on boot. |
| `DEPLOY_METHOD` | `docker` | Yes | Tells Rocket.Chat it's running via Docker, matches the official reference compose. |
| `MONGO_URL` | `mongodb://${{independent-reverence.RAILWAY_PRIVATE_DOMAIN}}:27017/rocketchat?replicaSet=rs0` | No | MongoDB connection string, must include the replica set name. Confirmed live resolves to `mongodb://independent-reverence.railway.internal:27017/rocketchat?replicaSet=rs0`. |

**Do NOT set a `PORT` variable** — confirmed live this breaks routing (see "Real Dead-End" above). Leave Railway's injected runtime `PORT` (8080) untouched.

## `independent-reverence` (MongoDB) App Variables

| Variable | Value | Mark Optional | Description |
|----------|-------|----------------|--------------|
| `MONGODB_ADVERTISED_HOSTNAME` | `${{RAILWAY_PRIVATE_DOMAIN}}` | No | Hostname the replica set member is registered under. Confirmed live resolves to `independent-reverence.railway.internal`. Must be reachable from the separate Rocket.Chat container, not `localhost`. |

## Platform-Injected `RAILWAY_*` Variables

Confirmed live via `railway variables --json` on both services. Standard treatment: mark optional = Yes, leave value empty, description "Railway platform setting, not specific to this template."

**rocketchat-railway**: `RAILWAY_ENVIRONMENT`, `RAILWAY_ENVIRONMENT_ID`, `RAILWAY_ENVIRONMENT_NAME`, `RAILWAY_PRIVATE_DOMAIN`, `RAILWAY_PROJECT_ID`, `RAILWAY_PROJECT_NAME`, `RAILWAY_PUBLIC_DOMAIN`, `RAILWAY_SERVICE_ID`, `RAILWAY_SERVICE_NAME`, `RAILWAY_SERVICE_ROCKETCHAT_RAILWAY_URL`, `RAILWAY_STATIC_URL`.

**independent-reverence**: `RAILWAY_ENVIRONMENT`, `RAILWAY_ENVIRONMENT_ID`, `RAILWAY_ENVIRONMENT_NAME`, `RAILWAY_PRIVATE_DOMAIN`, `RAILWAY_PROJECT_ID`, `RAILWAY_PROJECT_NAME`, `RAILWAY_SERVICE_ID`, `RAILWAY_SERVICE_NAME`, `RAILWAY_VOLUME_ID`, `RAILWAY_VOLUME_MOUNT_PATH` (confirms `/data/db`), `RAILWAY_VOLUME_NAME`.

**`RAILWAY_DEPLOYMENT_DRAINING_SECONDS` was not present in `railway variables --json` on either service at time of writing** — per this project's standing pattern, it may still surface in the composer UI directly even though it's absent from the CLI variable list. If it appears live, use the standard description: "Railway platform setting controlling deployment shutdown grace period. Not specific to this template, safe to leave unset."

## Volume

- **independent-reverence mount path:** `/data/db` (confirmed live via `RAILWAY_VOLUME_MOUNT_PATH`)
- **Volume name:** `independent-reverence-volume`
- **Purpose:** Holds all Rocket.Chat data (messages, users, files via GridFS, and the replica set's own oplog). Without this volume, every redeploy wipes everything, including the replica set configuration itself.
- **rocketchat-railway needs no volume** — confirmed, stateless, all data lives in MongoDB.

## Known Troubleshooting

- **If MongoDB crashes on boot with a bash syntax error**, check the wrapper script for apostrophes inside any `${VAR:?message}` construct, this is a real, confirmed bash parsing quirk, not a one-off. Run `bash -n` locally before trusting any future edit to this file.
- **If Rocket.Chat crashes on boot with `$ROOT_URL, if specified, must be an URL`**, the domain wasn't generated before `ROOT_URL` was set/evaluated. Generate the domain, then redeploy.
- **If the domain returns `404 Application not found`**, the deployment likely never passed its healthcheck gate, confirm the healthcheck path is `/api/info`, not `/api/v1/info`.
- **If the domain returns `502 Application failed to respond`**, check whether a `PORT` variable is set, it shouldn't be, remove it and let Railway's injected runtime port flow through.
- **If Rocket.Chat can't connect to MongoDB**, check `MONGO_URL` includes `?replicaSet=rs0` exactly, and confirm the MongoDB service's replica set actually initiated (check its logs for the `Initiating replica set rs0` line from the wrapper script's own echo).

## Post-Deploy Steps

1. Confirm the MongoDB replica set actually initiated (real proof via logs) — already confirmed on this deploy.
2. Complete a real admin registration (via the setup wizard in browser, or the REST API as done here) — already confirmed working live.
3. Log in with the created account and confirm `"roles":["user","admin"]` — already confirmed live.
4. Optional final check for Shruti: a real two-browser-session real-time message test (send in one, confirm it appears live in the other without refresh), the one thing this whole architecture exists to make actually work.

Status: Rocket.Chat template fully built, pushed, deployed, and functionally verified (real registration + login test passed, MongoDB replica set confirmed genuinely initiated). Two real bugs found and fixed live (bash apostrophe parsing quirk, ROOT_URL-before-domain ordering), plus one dead-end investigated and correctly resolved (no PORT override needed, unlike Appsmith). Composer checklist finalized with real live values in the same session as verification, per this project's standing rule.
