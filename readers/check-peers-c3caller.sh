#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_active() {
  local rpc="$1" chain="$2" ids_ok
  ids=$(cast call $C3CALLER "getAllActiveChainIDs()(string[])" --rpc-url $rpc | tr -d '"[]' | tr ',' ' ')
  active1=$(cast call $C3CALLER "isActiveChainID(string)(bool)" 1 --rpc-url $rpc)
  active59144=$(cast call $C3CALLER "isActiveChainID(string)(bool)" 59144 --rpc-url $rpc)
  if ok_has_id 1 $ids && ok_has_id 59144 $ids; then
    ids_ok=$(_status ok)
  else
    ids_ok=$(_status MISMATCH)
  fi
  say C3Caller "$chain" "active chain IDs" "$ids" "$ids_ok"
  say C3Caller "$chain" "chain ID 1 active" "$active1" "$(ok_true "$active1")"
  say C3Caller "$chain" "chain ID 59144 active" "$active59144" "$(ok_true "$active59144")"
}

print_active mainnet-rpc-url Ethereum
echo
print_active linea-rpc-url Linea
