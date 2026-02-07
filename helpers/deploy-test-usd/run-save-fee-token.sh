#!/bin/bash
# Updates deployments.toml ([chainId.address].fee_token) and fee-token.json from broadcast/DeployFeeToken.s.sol.
# Usage: run-save-fee-token.sh <chain-name>
# Example: run-save-fee-token.sh arbitrum-sepolia
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
(cd "$ROOT" && node js-helpers/save-fee-token.js "$1")
