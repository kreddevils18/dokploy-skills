#!/usr/bin/env bash
# Read-only Swarm status for one Dokploy Application: update status, recent
# task states and the last log lines with long tokens masked.
# Usage: swarm-status.sh <ssh-target> <swarm-service> [since]
#   ssh-target   e.g. root@my-server (reached with `tailscale ssh`, or plain ssh
#                when SWARM_STATUS_SSH=ssh)
#   swarm-service the suffixed Dokploy App Name, e.g. myapp-api-25yhjl
#   since        log window for `docker service logs --since` (default 3m)
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <ssh-target> <swarm-service> [since]" >&2
  exit 2
fi
target=$1
service=$2
since=${3:-3m}
case "$service$since" in
  *[!A-Za-z0-9._-]*) echo "service and since may contain only letters, digits, . _ -" >&2; exit 2 ;;
esac

ssh_cmd=${SWARM_STATUS_SSH:-tailscale ssh}

# shellcheck disable=SC2086
$ssh_cmd "$target" "
  echo '== update status'
  docker service inspect '$service' --format '{{.UpdatedAt}} {{json .UpdateStatus}}'
  echo '== tasks'
  docker service ps '$service' --no-trunc --format '{{.CurrentState}} | {{.Error}}' | head -6
  echo '== logs (since $since)'
  docker service logs --since '$since' --tail 30 '$service' 2>&1 | cut -c1-400
" | sed -E 's/[A-Za-z0-9_+\/=-]{28,}/[masked]/g'
