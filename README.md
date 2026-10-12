# Nook — stabilized full-stack social app

Nook is a chats-first social app built around actual conversations and small-group connection rather than an endless-scroll feed.

This package is a **production-oriented source package**, not a claim that a remote Supabase project has already been deployed and live-tested. The included frontend, database migration, Edge Function, and C++ shell are wired together, but the final production checks still have to be run against the target Supabase/Cloudflare/hosting accounts.

## What was repaired

- Removed the production path's dependency on demo/local social data after authentication.
- Removed localStorage as the source of truth for profiles, follows, blocks and settings.
- Real Supabase Auth session handling with profile creation.
- Real posts, likes, saves, comments and audience controls.
- Real direct/group conversations and persistent messages.
- Real photo/video/voice uploads to private Storage.
- Signed media URLs instead of persistent public media URLs.
- Real message reactions, deletion and disappearing-message expiry.
- Real follow requests, blocks and notification persistence.
- Real reports.
- Active Moments are persisted for 24 hours.
- Batched social/message loading to avoid the old per-post/per-chat query explosion.
- Realtime messages, reactions, notifications and membership refreshes.
- Private Realtime signaling for WebRTC calls.
- Server-side call privacy checks.
- Short-lived Cloudflare TURN credentials through an authenticated Edge Function.
- C++ desktop crash recovery and safer local-content settings.
- Startup error boundary so backend failures are shown instead of becoming a blank screen.

## Directory

```text
Nook_Stabilized/
├── web/
│   ├── nook.html
│   ├── config.js
│   └── config.example.js
├── sql/
│   └── nook_backend.sql
├── supabase/
│   └── functions/
│       └── turn-credentials/
│           ├── index.ts
│           └── README.md
└── desktop/
    ├── CMakeLists.txt
    └── main.cpp
```

## 1. Deploy the database

Run `sql/nook_backend.sql` in the target Supabase project's SQL editor or migration pipeline.

The migration creates:

- Auth-linked profiles
- follows and private follow requests
- blocks
- posts/comments/likes/saves
- conversations/members/messages/reactions
- notifications
- Moments + views
- reports
- private `nook-media` Storage
- RLS policies
- Realtime publication
- private call/presence authorization
- server-side messaging/call privacy checks
- cleanup support for expired messages/Moments

The SQL is intentionally the deployment source of truth; the previous package only contained a short manifest and therefore could not recreate the backend.

## 2. Configure the web client

`web/config.js` must contain only the Supabase project URL and publishable key.

Never put:

- Supabase service-role keys
- Cloudflare TURN API tokens
- other server secrets

in browser files.

Run locally with:

```bash
python -m http.server 8080 --directory web
```

Open:

```text
http://localhost:8080/nook.html
```

## 3. Configure TURN

The WebRTC client calls the authenticated `turn-credentials` Edge Function.

Set these Supabase Edge Function secrets:

```bash
supabase secrets set   CLOUDFLARE_TURN_KEY_ID=...   CLOUDFLARE_TURN_API_TOKEN=...
```

Then deploy:

```bash
supabase functions deploy turn-credentials
```

The Cloudflare token never reaches the browser.

## 4. Supabase Auth

Enable the email/password provider in Supabase Authentication.

If email confirmation is enabled, a new account will receive the confirmation flow before it can sign in.

The database trigger creates a profile automatically from the Auth user's metadata (including the requested handle), with collision-safe handle generation. The client then completes the profile without pretending that browser state is authoritative.

## 5. Realtime

The SQL migration adds the required tables to `supabase_realtime` and enables private channel authorization for:

- message events
- notification events
- membership refreshes
- message reactions
- WebRTC call signaling
- private presence

## 6. Desktop

Requirements:

- Qt 6 Widgets
- Qt 6 WebEngineWidgets
- CMake 3.21+
- C++17 compiler

Build:

```bash
cmake -S desktop -B desktop/build
cmake --build desktop/build --config Release
```

The desktop wrapper uses the same web client and backend.

## Verification status

Verified from the supplied source package in this repair pass:

- JavaScript syntax: **PASS**
- Production/demo path audit: **PASS — remaining local-only actions were identified and replaced**
- Backend migration completeness: **REPAIRED + Auth profile trigger included**
- Edge Function source included: **PASS**
- C++ source reviewed and crash recovery improved: **PASS**
- Qt binary build: **NOT run here because Qt WebEngine headers are not installed in the repair environment**
- Real Supabase Auth/database/storage/realtime/TURN end-to-end test: **REQUIRES the target project's credentials and deployment**
- App-store/browser production deployment: **REQUIRES the target hosting account**

Do not treat a green source audit as proof of a live deployment. The final release gate is an end-to-end test with two real accounts on the deployed environment.
