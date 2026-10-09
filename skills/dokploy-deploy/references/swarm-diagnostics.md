# Swarm diagnostics

Dokploy Applications are Docker Swarm services named by their suffixed App
Name. When the MCP is not enough, inspect the service on the manager node over
SSH (for example `tailscale ssh root@<host> '<command>'`). Ask first if your
agent's permission rules block it. `scripts/swarm-status.sh` bundles the read-only checks below.

## Read the real state

```bash
docker service inspect <svc> --format '{{.UpdatedAt}} {{json .UpdateStatus}}'
docker service ps <svc> --no-trunc --format '{{.CurrentState}} | {{.Error}}' | head
docker service logs --since 3m --tail 30 <svc> 2>&1 | sed -E 's/[A-Za-z0-9_+\/=-]{28,}/[masked]/g'
```

`UpdateStatus.State`:

- `completed`: the latest spec rolled out.
- `null`: first deploy, or no update since creation; judge by task state.
- `paused`: an update failed and `FailureAction: pause` kept the new spec; the message names the failed task.
- `rollback_completed`: an update failed and Swarm restored the previous spec. Tasks now run the **old** env and image.

Check one env name without printing values:

```bash
docker service inspect <svc> --format '{{range .Spec.TaskTemplate.ContainerSpec.Env}}{{println .}}{{end}}' \
  | awk -F= '/^NAME=/{print $1": "(length(substr($0,index($0,"=")+1))>0?"SET":"EMPTY")}'
```

## The rollback trap

Symptom: you fix an env value, redeploy, the deployment says `done`, yet the
container logs repeat the old error. Cause: on the first failed update, Swarm
rolled back to the original (broken) spec, and each later update also fails, for
a different reason, and rolls back again. The visible logs come from the old
spec, so they hide the new failure.

Diagnose:

1. Confirm `UpdateStatus.State` is `rollback_completed` and that the spec env still shows the old values (SET/EMPTY check above).
2. Temporarily set the service's `updateConfigSwarm.FailureAction` to `"pause"` with `application-update`. Rolling back to a spec that never worked has no value anyway.
3. Redeploy. The new spec stays in place, so `docker service logs --since 2m` shows the real startup error. Fix it, redeploy, and repeat until the update reaches `completed` and health checks pass.
4. Restore `FailureAction: "rollback"` once the service is healthy.

While paused, a deploy that fails before building (for example `Invalid environment variable`) leaves `UpdatedAt` unchanged; check the deployment log when `UpdatedAt` does not move.

## Crash-loop triage

- Read runtime logs, not build logs. A green build plus a Cloudflare `502` means the task never became healthy.
- Common startup failures are configuration checks: a feature's optional group partly filled (keys present but an enabling URL missing, or the reverse), a webhook secret in the wrong format for the environment, an enum variable holding a different variable's value, an object-storage endpoint containing a path.
- If a validator printed a secret into the logs, it is now in Docker and Dokploy logs: tell the user and recommend rotating that credential.

## One-off containers on the Dokploy network

To run an operator command against the environment's database with the
service's own env and without exposing Postgres:

```bash
docker run --rm -it --network dokploy-network \
  --env-file <(docker service inspect <svc> --format '{{range .Spec.TaskTemplate.ContainerSpec.Env}}{{println .}}{{end}}') \
  --entrypoint sh -w <workdir> <svc>:latest -c '<command>'
```

Run it on the manager node (the image and the Swarm env live there, not on the
laptop), interactively when it prompts for a password. Commands that need a
password should prompt with echo off, never take it as a flag.
