# Access and routing

Decide each surface's audience first: public internet, operator only, or
third-party callers (webhooks, media fetches, OAuth providers).

## Public HTTPS behind Cloudflare

- Create the DNS record in Cloudflare (proxied) pointing at the server, then a Dokploy domain with `https: true` and Let's Encrypt. Copy the pattern from a domain that already works on the same server.
- Apps behind Cloudflare usually trust `cf-connecting-ip` for client IPs; that only holds when the origin is reachable through Cloudflare, so do not also expose the origin directly.
- Anything third parties must call (payment webhooks, platform media pulls, OAuth back-channels) has to stay public and outside any login gate.

## Private service over a Tailscale Service

Use for operator-only tools (admin panels, dashboards).

1. Publish the container port on the host with `port-create` (choose a free host port; list current ones with `docker-getContainers`).
2. On the server, which must be a **tagged** tailnet node (`service hosts must be tagged nodes` otherwise), run:
   `tailscale serve --bg --service=svc:<name> --https=443 http://127.0.0.1:<host-port>`
   Run it on the server, not the laptop. `tailscale serve status` and `tailscale debug prefs` (AdvertiseServices) confirm it.
3. The user approves `svc:<name>` in the Tailscale admin console (Services).
4. The tailnet policy must grant clients access to `svc:<name>`. Existing services are often listed one by one in a grant's `dst`; add the new one there. Symptom of a missing grant: the hostname resolves to a service VIP but connections time out, and the client's netmap (`tailscale status --json`, peer `AllowedIPs`) lacks that VIP.
5. Set the app's own origin variable (for example `ADMIN_URL=https://<name>.<tailnet>.ts.net`).
6. Verify: `curl 127.0.0.1:<host-port>/<health>` on the server, the ts.net URL from a tailnet client, and that `http://<public-ip>:<host-port>` is refused (provider firewall).

Remove with `tailscale serve clear svc:<name>` on the server.

### Alternative: a Tailscale sidecar node

Instead of publishing a host port, run a `tailscale/tailscale` container as its
own tailnet node (for example hostname `<name>`) on the Dokploy network, with
`tailscale serve` inside it proxying to `http://<app-appname>:<container-port>`.
Nothing is published on the host, so the Swarm/UFW exposure risk disappears.
Costs: one more container to keep running, an auth key or OAuth client to
provision and rotate, a node name instead of a `svc:` name, and ACLs that
target that node or its tag. Prefer it when the provider firewall cannot be
managed or the host has no free port; prefer the Tailscale Service when the
server node already serves other services and a host port can be firewalled.

Caveat: an app that only trusts Cloudflare client-IP headers receives none over Tailscale, so per-IP rate limits see no client address.

## Gate a public site with Cloudflare Access

Use when the site must stay on a public hostname (third-party constraints) but
only the operator should use it. No code changes.

1. Keep third-party-facing surfaces (API, webhooks, media) on a separate hostname and leave them outside Access.
2. Cloudflare One → Access controls → Applications → Create new application → Self-hosted and private → public hostname (subdomain + zone), whole path. The Cloudflare MCP has no Access tools; do it in the dashboard (the user signs in; you never enter credentials).
3. Create an Allow policy: Include → Emails → the operator's address. Access denies by default, so an app with no policy blocks everyone.
4. Show the configuration and let the user confirm before **Create**.
5. Make sure server-to-server calls between your own services use internal network URLs, not the gated public hostname.
6. Verify: anonymous `curl -I https://<site>/` returns `302` to `<team>.cloudflareaccess.com`; the API health endpoint still returns `200`.

Side effects to report: machine clients that call the gated hostname from outside a browser (CLI device login, remote MCP connectors, external OAuth metadata fetches) are blocked until you add a Bypass or Service Auth policy for those paths.

## Why not move a web app behind the VPN while its API stays public

Browser flows that rely on a `SameSite=Lax` cookie set by the API and read back
from the web origin break when web and API are on different sites (for example
`*.ts.net` versus your domain): the browser does not send the cookie on
cross-site requests. Check for such cookies (OAuth state, session binding)
before splitting sites. CORS restricts browsers only; it is not an access
control for an API, which relies on authentication, signed public routes and
rate limits.
