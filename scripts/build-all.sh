#!/usr/bin/env bash
# Common build and staging sequence for containers and direct CI.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
scripts/build.sh
scripts/kernel.sh
tests/modules.sh
scripts/base.sh
scripts/prepare-test-root.sh
