#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

ACCOUNT=""
PASSWORD_FILE=""
CHAIN_ID=""
DESTINATION_CHAIN_ID=""
STATUS=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --account)
      ACCOUNT="$2"
      shift 2
      ;;
    --password-file)
      PASSWORD_FILE="$2"
      shift 2
      ;;
    --chain-id)
      CHAIN_ID="$2"
      shift 2
      ;;
    --destination-chain-id)
      DESTINATION_CHAIN_ID="$2"
      shift 2
      ;;
    --status)
      STATUS="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$ACCOUNT" || -z "$PASSWORD_FILE" || -z "$CHAIN_ID" || -z "$STATUS" ]]; then
  echo "Error: Missing required arguments."
  echo "Usage: $0 --account <ACCOUNT> --password-file <PATH> --chain-id <CHAIN_ID> --status <true|false> [--destination-chain-id <CHAIN_ID>]"
  echo "  --chain-id: chain where C3Caller is deployed (broadcast chain)."
  echo "  --destination-chain-id: optional; chain ID(s) to activate/deactivate. If omitted, all chain IDs from deployments.toml are used."
  echo "  --status: true = activateChainID, false = deactivateChainID."
  exit 1
fi

if [[ "$STATUS" != "true" && "$STATUS" != "false" ]]; then
  echo "Error: --status must be 'true' or 'false'."
  exit 1
fi

# Broadcast chain: where C3Caller is deployed (we send txs here)
BROADCAST_CHAIN_ID="$CHAIN_ID"
eval $(node "$PROJECT_ROOT/js-helpers/get-config-for-chain.js" --chain-id "$BROADCAST_CHAIN_ID")
RPC_URL="${!RPC_URL_ENV}"
[ -z "$RPC_URL" ] && { echo "Error: RPC URL env \$$RPC_URL_ENV not set."; exit 1; }

# Comma-separated chain ID strings for one Forge run (avoids nonce errors across multiple txs)
if [[ -n "$DESTINATION_CHAIN_ID" ]]; then
  CHAIN_IDS_CSV="$DESTINATION_CHAIN_ID"
else
  CHAIN_IDS_CSV=$(node "$PROJECT_ROOT/js-helpers/get-all-chain-ids.js" | paste -sd, -)
fi

[[ -z "$CHAIN_IDS_CSV" ]] && { echo "Error: No chain IDs to set."; exit 1; }

export ACTIVE_STATUS="$STATUS"
export CHAIN_IDS="$CHAIN_IDS_CSV"

echo "=== Setting chain ID(s) to active=$STATUS (broadcast chain $BROADCAST_CHAIN_ID) ==="
forge script script/SetActiveStatus.s.sol \
  --account "$ACCOUNT" \
  --password-file "$PASSWORD_FILE" \
  --rpc-url "$RPC_URL" \
  --chain-id "$BROADCAST_CHAIN_ID" \
  --broadcast

if [[ $? -ne 0 ]]; then
  echo "Forge script failed. Exiting."
  exit 1
fi

echo "SetActiveStatus complete."
