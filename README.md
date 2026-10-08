# turn-credentials

Authenticated Edge Function that returns short-lived Cloudflare TURN ICE servers.

Set these server-side secrets before deployment:

- `CLOUDFLARE_TURN_KEY_ID`
- `CLOUDFLARE_TURN_API_TOKEN`

Deploy with the Supabase CLI:

```bash
supabase functions deploy turn-credentials
supabase secrets set CLOUDFLARE_TURN_KEY_ID=... CLOUDFLARE_TURN_API_TOKEN=...
```

The browser must never receive the Cloudflare API token.
