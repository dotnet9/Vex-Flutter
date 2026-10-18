#!/usr/bin/env bash
set -euo pipefail
exec "${VEX_PYTHON:-python3}" "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/build.py" osx-arm64 "$@"
