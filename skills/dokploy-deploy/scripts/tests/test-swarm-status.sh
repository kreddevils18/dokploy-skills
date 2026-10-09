#!/usr/bin/env bash
# Offline tests for swarm-status.sh: argument validation and output masking,
# using a fake SSH command instead of a real server.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
script="$here/../swarm-status.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }

# Missing arguments exit 2.
if "$script" >/dev/null 2>&1; then fail "no args should fail"; fi
code=0; "$script" host >/dev/null 2>&1 || code=$?; [ "$code" = 2 ] || fail "one arg should exit 2, got $code"

# Unsafe service names are rejected before any SSH call.
code=0; SWARM_STATUS_SSH=false "$script" host 'svc;rm -rf /' >/dev/null 2>&1 || code=$?; [ "$code" = 2 ] || fail "unsafe service should exit 2, got $code"

# Long tokens in remote output are masked; normal words survive.
fake=$(mktemp); trap 'rm -f "$fake"' EXIT
cat > "$fake" <<'FAKE'
#!/usr/bin/env bash
echo 'error: unsupported value "fake_token_0123456789abcdef0123456789abcdef"'
echo 'API starting environment=staging'
FAKE
chmod +x "$fake"
out=$(SWARM_STATUS_SSH="$fake" "$script" root@host myapp-api-abc123 5m)
case "$out" in *0123456789abcdef0123456789abcdef*) fail "token not masked: $out" ;; esac
case "$out" in *"[masked]"*) ;; *) fail "mask marker missing: $out" ;; esac
case "$out" in *"API starting environment=staging"*) ;; *) fail "normal line lost: $out" ;; esac
echo "ok"
