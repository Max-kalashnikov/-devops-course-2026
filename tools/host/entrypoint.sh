#!/usr/bin/env bash
set -euo pipefail
install -m 600 /run/client-key /root/.ssh/devops_vm
install -m 600 /run/client-hosts /root/.ssh/known_hosts
cat > /root/.ssh/config <<'CONFIG'
Host devops
    HostName host.docker.internal
    Port 2222
    User devops
    IdentityFile /root/.ssh/devops_vm
    IdentitiesOnly yes
    StrictHostKeyChecking yes
Host devops.local
    HostName devops.local
    Port 2222
    User devops
    IdentityFile /root/.ssh/devops_vm
    IdentitiesOnly yes
    StrictHostKeyChecking yes
CONFIG
chmod 600 /root/.ssh/config
if [[ -f /run/client-cert ]]; then cp /run/client-cert /root/devops.crt; fi
exec bash -c "$1"
