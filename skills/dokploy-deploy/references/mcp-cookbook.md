# Dokploy MCP cookbook

Tool names below drop the `mcp__dokploy-mcp__` prefix. The server exposes
hundreds of deferred tools; load the ones you need in one ToolSearch call, for
example `select:project-all,environment-one,application-one,application-create,application-saveGithubProvider,application-saveBuildType,application-update,application-saveEnvironment,domain-create,port-create,application-deploy,deployment-all,deployment-readLogs,application-readLogs`.

## Behaviour to expect

- Every env, build-arg, password and token value comes back as `[REDACTED]`, even when empty. You cannot tell from the MCP whether an environment block is filled.
- `application-create` returns the real `appName` with a random suffix (`myapp-api` → `myapp-api-25yhjl`). Internal URLs (`http://<appName>:<port>`) and `docker service` commands use that suffixed name.
- New apps default to `buildType: nixpacks`, `autoDeploy: true`, `dockerfile: "Dockerfile"`. Change all three.
- `application-readLogs` with `search` returns HTTP 500; fetch without `search` and filter locally. It only returns logs of recent containers.
- `deployment-*` `status: done` means the image was built and the service updated. It does not mean the container is healthy, and a Swarm rollback leaves it `done`.
- Calls that change source, build type or env do not redeploy; the next `application-deploy` applies them.
- Dokploy's dashboard is usually reachable only over the tailnet (`DOKPLOY_URL` in the MCP config, for example `http://<host>:3000`). In a logged-in browser, `fetch('/api/trpc/<router>.<proc>?input=' + encodeURIComponent(JSON.stringify({json:{...}})))` returns unredacted records; use it only to check presence or shape (SET/EMPTY, references), never to display values.

## Configure an Application

| Step | Tool | Notes |
|---|---|---|
| Create | `application-create` `{name, appName, environmentId, sourceType: "github"}` | Keep the returned `applicationId` and suffixed `appName`. |
| Source | `application-saveGithubProvider` `{applicationId, githubId, owner, repository, branch, buildPath: "/", triggerType: "push", enableSubmodules: false}` | Copy `githubId` from an existing app (`application-one` → `githubId`) or `github-githubProviders`. Monorepos build from `/`. |
| Build | `application-saveBuildType` `{applicationId, buildType: "dockerfile", dockerfile: "<path>", dockerContextPath: ".", dockerBuildStage: "<stage>", herokuVersion: null, railpackVersion: null}` | `herokuVersion` and `railpackVersion` are required keys; pass `null`. |
| Swarm and flags | `application-update` `{applicationId, autoDeploy: false, updateConfigSwarm: {...}, restartPolicySwarm: {...}, cpuLimit, memoryLimit}` | Long-running services: `{"Parallelism":1,"Order":"start-first","FailureAction":"rollback","Monitor":30000000000}` (Monitor in ns). One-shot jobs such as migrations: `restartPolicySwarm: {"Condition":"none"}`. Limits are strings in Docker units: 1 CPU `"1000000000"`, 1 GiB `"1073741824"`. |
| App env | `application-saveEnvironment` `{applicationId, env, buildArgs, buildSecrets, createEnvFile: true}` | All four keys are required; pass `null` for unused `buildArgs`/`buildSecrets`. Omitting them makes the client send invalid JSON. Put only `${{environment.NAME}}` references and non-secret literals here. Build-time values (for example `NEXT_PUBLIC_*`) go in `buildArgs` and need a rebuild to change. |
| Public domain | `domain-create` `{applicationId, host, port, path: "/", https: true, certificateType: "letsencrypt", domainType: "application"}` | Works behind a Cloudflare-proxied record when HTTP-01 reaches Traefik; check an existing working domain on the same server for the pattern. |
| Host port | `port-create` `{applicationId, publishedPort, targetPort, protocol: "tcp", publishMode: "ingress"}` | Swarm publishes on every interface, including the public IP, and bypasses UFW. Block the port at the provider firewall and verify from outside. |
| Deploy | `application-deploy` `{applicationId, title}` | Then poll `deployment-all` and read `deployment-readLogs` (build) and `application-readLogs` (runtime). |

Verify a batch of apps cheaply through the dashboard session (branch, autodeploy,
stage) instead of five verbose `application-one` calls.

## Environment variables

- Levels: project (`${{project.X}}`, shared by all environments), environment (`${{environment.X}}`, per environment), service (literal in the app). Resolution happens at deploy time; a reference to a missing name fails the deploy at "Initializing deployment" with `Invalid environment variable: environment.X`.
- UI locations (Dokploy v0.30): project page → choose the environment in the header selector → the small terminal-square icon beside it opens **Environment Variables** for that environment. The **Project Environment** button on the right is project level.
- `environment-update` with `env` replaces the whole block. Only use it on a block you know is empty or when the user explicitly hands you every value.
- Give the user a template with every name the apps reference, non-secret values filled (`APP_ENV`, public URLs, internal URLs with suffixed App Names, DB host) and placeholders for secrets. Keep unused optional names present but empty when the apps reference them.
- Watch for mixed-up values (a key in a tuning variable, an endpoint with a path where a host is expected). Validators that echo the value will print it into logs.

## Release order and checks

Deploy dependencies first. For an app with migrations: migrate (wait for the task to exit 0 and the logs to show migrations applied) → API → background workers → web → admin. Read each app's runtime logs and wait past the Swarm monitor window before moving on. Redeploy every app whose template references a changed variable, even when its code did not change.
