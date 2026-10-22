#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Quickshell supplies platform-dependent types at runtime. The four metadata
# exceptions are documented locally, beside the corresponding declarations.
mapfile -t files < <(find src -name '*.qml' -type f | sort)
qmllint -E --unqualified disable --max-warnings 0 "${files[@]}"
