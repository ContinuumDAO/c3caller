#!/bin/bash
# Updates contract-addresses.json and (when broadcast exists) patches deployments.toml with new addresses.
# Call after deploy. PROJECT_ROOT can be set by caller; otherwise derived from this script's path.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
(cd "$ROOT" && node js-helpers/0-save-contract-addresses.js")
