#!/usr/bin/env bash
#
# Run every validator test suite (Python, Node.js, Bash).
#
# Usage:
#   bash tests/run-all.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

echo "==> Python tests"
python3 -m unittest tests/test_python.py

echo
echo "==> Node.js tests"
node --test tests/test_node.js

echo
echo "==> Bash tests"
bash tests/test_bash.sh

echo
echo "All validator test suites passed."
