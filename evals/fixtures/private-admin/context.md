Dokploy staging for shopnote: web and api are public behind Cloudflare. The `admin` Application (container port 3001,
health `GET /healthz`) must be reachable only by the owner, at https://shopnote-admin.tail1234.ts.net .
The Dokploy server is tailnet node `vps-1` (tagged `tag:server`); the owner's laptop is node `laptop` on the same tailnet.
Admin reads its public origin from ADMIN_URL. The provider is Hetzner; UFW is enabled on the host.
