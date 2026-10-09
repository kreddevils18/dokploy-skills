The first deploy of `api` (service shopnote-api-25yhjl) crashed because TIKTOK_CLIENT_KEY and TIKTOK_CLIENT_SECRET were empty.
The user then filled the TikTok keys in the staging Environment Variables and redeployed api three times. Every deployment says "done", Cloudflare still returns 502 for /healthz, and the logs keep showing the same TikTok error.
Read-only SSH to the Swarm manager is available if needed.
