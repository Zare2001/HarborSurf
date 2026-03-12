#!/bin/bash
# Host prep for Harbor over HTTP (mirrors plugin-vantage style: run on workspace before/after compose).
# Research Cloud or manual: run as root after Docker is installed.
#
# Usage:
#   sudo HARBOR_HOSTNAME=145.38.205.248 ./init.sh
#   sudo ./init.sh 145.38.205.248
#
# Ensures Docker accepts HTTP registry at HARBOR_HOSTNAME so docker login/push work on this host.

set -e

HARBOR_HOSTNAME="${HARBOR_HOSTNAME:-$1}"
if [ -z "$HARBOR_HOSTNAME" ] || [ "$HARBOR_HOSTNAME" = "127.0.0.1" ] || [ "$HARBOR_HOSTNAME" = "localhost" ]; then
  echo "Usage: sudo HARBOR_HOSTNAME=<IP> $0   or   sudo $0 <IP>"
  exit 1
fi

DAEMON_JSON="/etc/docker/daemon.json"
mkdir -p /etc/docker

if command -v python3 &>/dev/null; then
  python3 << PY
import json, os
path = "$DAEMON_JSON"
host = "$HARBOR_HOSTNAME"
if os.path.exists(path):
    with open(path) as f:
        try:
            d = json.load(f)
        except json.JSONDecodeError:
            d = {}
else:
    d = {}
if not isinstance(d, dict):
    d = {}
if "insecure-registries" not in d or not isinstance(d["insecure-registries"], list):
    d["insecure-registries"] = []
if host not in d["insecure-registries"]:
    d["insecure-registries"].append(host)
with open(path, "w") as f:
    json.dump(d, f, indent=2)
PY
else
  # Fallback: overwrite only if missing (may lose other keys)
  if [ ! -f "$DAEMON_JSON" ]; then
    echo "{\"insecure-registries\": [\"$HARBOR_HOSTNAME\"]}" > "$DAEMON_JSON"
  else
    echo "python3 not found; merge manually into $DAEMON_JSON:"
    echo "  \"insecure-registries\": [\"$HARBOR_HOSTNAME\"]"
    exit 1
  fi
fi

chmod 644 "$DAEMON_JSON"
systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true
echo "Docker configured for insecure registry: $HARBOR_HOSTNAME"
echo "Run: docker login $HARBOR_HOSTNAME"
