# dokploy-skills

[Agent Skills](https://developers.openai.com/codex/skills) for deploying and debugging multi-service apps on a self-hosted [Dokploy](https://dokploy.com) server. They use the open `SKILL.md` format, so the same folder works in Codex, Claude Code, Cursor, OpenCode and other agents that read skills.

The `dokploy-deploy` skill turns "ship this branch to staging" into a checked release: the agent inspects the environment, writes a release plan, configures each Application through the Dokploy MCP, deploys in dependency order and checks every health endpoint. When a container keeps crashing, it reads the Swarm state instead of redeploying blindly.

It was written from a real staging release of a five-service monorepo (migrate, API, worker, web, admin) and the problems that release hit.

## Install

With the [skills CLI](https://github.com/vercel-labs/skills), for any supported agent:

```sh
npx skills add kreddevils18/dokploy-skills
```

It asks which agents to install for. To skip the questions, name them and install for every project (`-g`):

```sh
npx skills add kreddevils18/dokploy-skills -g -a codex -a claude-code
```

Or copy the folder yourself:

| Agent | Every project | One repository |
| --- | --- | --- |
| Codex | `~/.agents/skills/dokploy-deploy` | `.agents/skills/dokploy-deploy` |
| Claude Code | `~/.claude/skills/dokploy-deploy` | `.claude/skills/dokploy-deploy` |
| Other agents | the agent's skills folder | the agent's project skills folder |

```sh
git clone https://github.com/kreddevils18/dokploy-skills
cp -R dokploy-skills/skills/dokploy-deploy ~/.agents/skills/
```

Claude Code can also install it as a plugin:

```sh
claude plugin marketplace add kreddevils18/dokploy-skills
claude plugin install dokploy-deploy@dokploy-skills
```

Keep one copy per agent, or the agent sees the skill twice. Restart the agent (or run `/reload-plugins` in Claude Code) after installing.

## Use

Talk to your agent normally. The skill loads when the request is about Dokploy, including crash reports that only show logs from a Dokploy-hosted service. You can also pick it by name: `$dokploy-deploy` in Codex, `/dokploy-deploy` in Claude Code.

| You say | What the agent does |
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

- An agent that reads `SKILL.md` skills.
- The [Dokploy MCP server](https://github.com/Dokploy/mcp) connected to that agent, pointed at your Dokploy instance:

  ```sh
  # Claude Code
  claude mcp add dokploy -e DOKPLOY_URL=https://dokploy.example.com -e DOKPLOY_API_KEY=... -- npx -y @dokploy/mcp
  ```

  ```toml
  # Codex: ~/.codex/config.toml
  [mcp_servers.dokploy]
  command = "npx"
  args = ["-y", "@dokploy/mcp"]
  env = { DOKPLOY_URL = "https://dokploy.example.com", DOKPLOY_API_KEY = "..." }
  ```

- Optional, for server-side checks: SSH to the Swarm manager. The examples use `tailscale ssh root@<host>`; plain `ssh` works with `SWARM_STATUS_SSH=ssh`.
- Optional: `curl`, `dig`, and the AWS CLI for S3-compatible storage copies.

## What it does on your machine

The skill is instructions plus one read-only shell script. It acts only through tools you already gave your agent: the Dokploy MCP, a shell and, when you ask, a browser.

- It never prints, commits or pastes secret values. The Dokploy MCP redacts env values and the skill does not work around that. Values that must move between systems go through a mode-600 temp file that is deleted afterwards, and long tokens in logs are masked.
- You fill secrets in the Dokploy UI. It will not overwrite an environment's variable block through the API unless that block is known to be empty.
- It asks before destructive or outward actions: deleting services, volumes or branches, changing database or auth secrets, writing to a database (always after a backup), publishing ports, changing tailnet policy, or touching production.
- `scripts/swarm-status.sh <ssh-target> <service> [since]` only runs `docker service inspect`, `docker service ps` and `docker service logs` over SSH, and masks long tokens in what it prints.

Read the skill before you install it: `skills/dokploy-deploy/SKILL.md` and four reference files.

## Evaluation

`evals/` holds five fictional cases (three train, two holdout) with fixtures, and eight routing probes. The runs below used Claude Code (`claude -p`, Opus) in fresh sessions with no MCP servers and no shell, so nothing touched a real server; a separate model graded anonymized outputs against the rubric. Other agents have not been evaluated yet.

| | Without the skill | With the skill |
| --- | --- | --- |
| Rubric assertions passed | 17/21 | 21/21 |
| Mean quality score (1-5) | 4.0 | 5.0 |
| Cost for the five cases | 2.09 USD | 2.88 USD |

The skill loaded for every Dokploy-worded request and for none of four near-miss requests (Vercel, Coolify, local Docker Compose, GitHub Actions). A request that showed only container logs, with Dokploy mentioned only in an attached file, loaded it 3 times out of 4. One run per case, so treat the numbers as directional. Results from other agents are welcome.

## Troubleshooting

- **The skill does not load.** Check that the folder sits in your agent's skills location and restart the agent (Codex lists skills with `/skills`; Claude Code with `/skills` or `/plugin`). Mention Dokploy in your request, or pick the skill by name.
- **The agent cannot see your Dokploy projects.** The Dokploy MCP server is not connected; check its `DOKPLOY_URL` and `DOKPLOY_API_KEY`.
- **Server checks are refused.** Your agent may treat SSH to a production host as a sensitive action and ask first. Allow it for that command, or run the printed command yourself.

## Contributing

Issues and pull requests are welcome, especially new failure patterns you hit on Dokploy and eval runs from other agents. Add a fictional eval case under `evals/` when you change behaviour, and run `bash skills/dokploy-deploy/scripts/tests/test-swarm-status.sh` before opening a pull request.

## License

[MIT](LICENSE)
