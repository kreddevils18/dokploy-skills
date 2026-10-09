# claude-dokploy-deploy

A [Claude Code](https://claude.com/claude-code) skill that deploys and debugs multi-service apps on a self-hosted [Dokploy](https://dokploy.com) server. Ask Claude to ship a branch to staging, and it inspects the environment, writes a release plan, configures each Application through the Dokploy MCP, deploys in dependency order and checks every health endpoint. When a container keeps crashing, it reads the Swarm state instead of redeploying blindly.

It was written from a real staging release of a five-service monorepo (migrate, API, worker, web, admin) and the problems that release hit.

## Install

```sh
claude plugin marketplace add kreddevils18/claude-dokploy-deploy
claude plugin install dokploy-deploy@claude-dokploy-deploy
```

The same two steps work inside a session as `/plugin marketplace add kreddevils18/claude-dokploy-deploy` and `/plugin install dokploy-deploy@claude-dokploy-deploy`. Then run `/reload-plugins`, or restart Claude Code.

Prefer a plain skill folder? Copy `skills/dokploy-deploy` to `~/.claude/skills/dokploy-deploy` (every project) or `.claude/skills/dokploy-deploy` (one project). Keep only one copy, or Claude sees the skill twice.

## Use

Talk to Claude normally. The skill loads when the request is about Dokploy, including logs-only crash reports from a Dokploy-hosted service. You can also call it by name: `/dokploy-deploy` (or `/dokploy-deploy:dokploy-deploy` when installed as a plugin).

| You say | What Claude does |
| --- | --- |
| "Deploy branch `release/1.2` to staging on Dokploy" | Inspects the environment, writes a release plan and env template, configures Applications, deploys in order, checks health |
| "The API keeps crashing after I fixed its env" | Reads the deploy log, the container logs and the Swarm update status, then explains the cause and the fix |
| "Make the admin app reachable only over Tailscale" | Publishes a free host port, sets up a Tailscale Service on the server, lists the approval and ACL steps, checks exposure |
| "Lock our staging site so only I can open it" | Walks through a Cloudflare Access self-hosted app with an email policy, keeping webhook hosts public |
| "Copy my local data into staging" | Backs up first, then copies only the rows and storage keys you choose, remapping owners |

## What it knows

| Area | Covered |
| --- | --- |
| Applications | GitHub source and branch, Dockerfile stage builds, autodeploy off, Swarm update and restart policies, resource limits, build args, domains, published ports |
| Variables | Environment-level values referenced as `${{environment.NAME}}`, why project level is shared by every environment, where the UI hides the environment editor, App Names with random suffixes |
| Releases | Dependency order (migrate first), per-step checks, health endpoints, what a `done` deployment does and does not prove |
| Diagnosis | `Invalid environment variable` failures, the `rollback_completed` trap where Swarm keeps running the old spec, the `pause` technique to see the real error, 502s behind Cloudflare |
| Access | Public HTTPS behind Cloudflare, Tailscale Services (tagged node, approval, ACL grant) or a sidecar node, Cloudflare Access, the cross-site cookie trap when web and API sit on different sites |
| Data | `pg_dump` backups inside the DB container, copying rows between environments with owner remapping, copying object-storage keys, creating an admin in a one-off container |

## Requirements

- Claude Code with skills or plugins (`claude --version`).
- The [Dokploy MCP server](https://github.com/Dokploy/mcp) configured for your Dokploy instance, for example `npx -y @dokploy/mcp` with `DOKPLOY_URL` and `DOKPLOY_API_KEY` in its environment.
- Optional, for server-side checks: SSH to the Swarm manager (the skill uses `tailscale ssh root@<host>` in its examples; plain `ssh` works with `SWARM_STATUS_SSH=ssh`).
- Optional: `curl`, `dig`, and the AWS CLI for S3-compatible storage copies.

## What it does on your machine

The skill is instructions plus one read-only shell script. It acts through tools you already granted Claude: the Dokploy MCP, your shell and, when you ask, a browser.

- It never prints, commits or pastes secret values. The Dokploy MCP redacts env values and the skill does not work around that. Values that must move between systems go through a mode-600 temp file that is deleted afterwards, and long tokens in logs are masked.
- You fill secrets in the Dokploy UI. It will not overwrite an environment's variable block through the API unless that block is known to be empty.
- It asks before destructive or outward actions: deleting services, volumes or branches, changing database or auth secrets, writing to a database (always after a backup), publishing ports, changing tailnet policy, or touching production.
- `scripts/swarm-status.sh <ssh-target> <service> [since]` only runs `docker service inspect`, `docker service ps` and `docker service logs` over SSH, and masks long tokens in what it prints.

Read the skill before you install it: `skills/dokploy-deploy/SKILL.md` and four reference files.

## Evaluation

`evals/` holds five fictional cases (three train, two holdout) with fixtures, and eight routing probes. Each run was a fresh `claude -p` session with no MCP servers and no shell, so nothing touched a real server; a separate model graded anonymized outputs against the rubric.

| | Without the skill | With the skill |
| --- | --- | --- |
| Rubric assertions passed | 17/21 | 21/21 |
| Mean quality score (1-5) | 4.0 | 5.0 |
| Cost for the five cases | 2.09 USD | 2.88 USD |

The skill loaded for every Dokploy-worded request and for none of four near-miss requests (Vercel, Coolify, local Docker Compose, GitHub Actions). A request that showed only container logs, with Dokploy mentioned only in an attached file, loaded it 3 times out of 4. One run per case, so treat the numbers as directional.

## Troubleshooting

- **The skill does not load.** Run `/plugin` and look for `dokploy-deploy`, then `/reload-plugins`. Mention Dokploy in your request, or call `/dokploy-deploy` directly.
- **Claude cannot see your Dokploy projects.** The Dokploy MCP server is not connected; check `/mcp` and the server's `DOKPLOY_URL` and `DOKPLOY_API_KEY`.
- **Server checks are refused.** Claude Code may treat SSH to a production host as a sensitive read and ask first. Allow it for that command, or run the printed command yourself.

## Contributing

Issues and pull requests are welcome, especially new failure patterns you hit on Dokploy. Add a fictional eval case under `evals/` when you change behaviour, and run `bash skills/dokploy-deploy/scripts/tests/test-swarm-status.sh` and `claude plugin validate .` before opening a pull request.

## License

[MIT](LICENSE)
