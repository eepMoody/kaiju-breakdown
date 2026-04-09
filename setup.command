#!/usr/bin/env bash
# Double-click this file in Finder to install project dependencies.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/setup.sh"

echo ""
echo "You can close this window now."
read -n 1 -s -r -p "Press any key to close..."
