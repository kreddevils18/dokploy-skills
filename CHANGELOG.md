# Changelog

## Unreleased

- Renamed the repository to `dokploy-skills` and made the skill agent-neutral: install with `npx skills` for Codex, Claude Code, Cursor and other agents, or copy the folder; the Claude Code plugin stays as one option.
- Skill wording no longer assumes Claude Code tools (`ToolSearch`, harness) or an AgentKit hand-off.

## 0.1.0 (2026-10-09)

- First release of the `dokploy-deploy` skill: release workflow, Dokploy MCP cookbook, Swarm diagnostics (rollback trap, pause technique), access and routing (Cloudflare, Tailscale Services or sidecar, Cloudflare Access), data operations, and the read-only `swarm-status.sh` script with tests.
- Eval cases, fixtures and routing probes under `evals/`.
