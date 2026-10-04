#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_wiring() {
  local rpc="$1" chain="$2"

  uuidKeeper=$(cast call $C3CALLER "uuidKeeper()(address)" --rpc-url $rpc)
  dappManager=$(cast call $C3CALLER "dappManager()(address)" --rpc-url $rpc)
  say C3Caller "$chain" uuidKeeper "$uuidKeeper" "$(ok_eq "$uuidKeeper" "$UUID_KEEPER")"
  say C3Caller "$chain" dappManager "$dappManager" "$(ok_eq "$dappManager" "$DAPP_MANAGER")"

  uuidC3=$(cast call $UUID_KEEPER "c3caller()(address)" --rpc-url $rpc)
  say C3UUIDKeeper "$chain" c3caller "$uuidC3" "$(ok_eq "$uuidC3" "$C3CALLER")"

  dmC3=$(cast call $DAPP_MANAGER "c3caller()(address)" --rpc-url $rpc)
  say C3DAppManager "$chain" c3caller "$dmC3" "$(ok_eq "$dmC3" "$C3CALLER")"

  govC3=$(cast call $C3GOV "c3caller()(address)" --rpc-url $rpc)
  govDappID=$(cast call $C3GOV "dappID()(uint256)" --rpc-url $rpc | awk '{print $1}')
  say C3Governor "$chain" c3caller "$govC3" "$(ok_eq "$govC3" "$C3CALLER")"
  say C3Governor "$chain" dappID "$govDappID" "$(ok_eq "$govDappID" "$DAPP_ID_C3GOV")"

  ctmC3=$(cast call $CTM "c3caller()(address)" --rpc-url $rpc)
  ctmDappID=$(cast call $CTM "dappID()(uint256)" --rpc-url $rpc | awk '{print $1}')
  say CTM "$chain" c3caller "$ctmC3" "$(ok_eq "$ctmC3" "$C3CALLER")"
  say CTM "$chain" dappID "$ctmDappID" "$(ok_eq "$ctmDappID" "$DAPP_ID_CTM")"
}

print_wiring mainnet-rpc-url Ethereum
echo
print_wiring linea-rpc-url Linea
