# shopnote
Monorepo: Go API (`apps/api`), Go worker (same binary family), Next.js web (`apps/web`), DB migrations run by a `migrate` job.
Dockerfile: `deploy/Dockerfile`, build context `.`, stages `migrate`, `api`, `worker`, `web`.
Health: API `GET /healthz` (port 8080), web `GET /api/health` (port 3000). Worker has no HTTP port; migrate runs once and exits.
API and worker refuse to start until migrations are applied. Web needs build arg `NEXT_PUBLIC_API_URL`.
Staging domains: web `shop.example.dev`, api `api.shop.example.dev` (Cloudflare proxied, already pointing at the server).
