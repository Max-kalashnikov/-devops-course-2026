#!/usr/bin/env bash
set -euo pipefail
export PATH="$(cygpath -u "$DEVOPS_HOST_BIN"):$PATH"
cd "$(cygpath -u "$DEVOPS_REPO")"
bash -c "$DEVOPS_COMMAND"
