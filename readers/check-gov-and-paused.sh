#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_gov_client() {
  local name="$1" addr="$2" rpc="$3" chain="$4"
  gov=$(cast call $addr "gov()(address)" --rpc-url $rpc)
  pending=$(cast call $addr "pendingGov()(address)" --rpc-url $rpc)
  paused=$(cast call $addr "paused()(bool)" --rpc-url $rpc)
  say "$name" "$chain" gov "$gov" "$(ok_eq "$gov" "$ADMIN")"
  say "$name" "$chain" pendingGov "$pending" "$(ok_eq "$pending" "$ZERO_ADDR")"
  say "$name" "$chain" paused "$paused" "$(ok_false "$paused")"
}

print_govern_dapp() {
  local name="$1" addr="$2" expected_dapp_id="$3" rpc="$4" chain="$5"
  gov=$(cast call $addr "gov()(address)" --rpc-url $rpc)
  delay=$(cast call $addr "delay()(uint256)" --rpc-url $rpc | awk '{print $1}')
  dappID=$(cast call $addr "dappID()(uint256)" --rpc-url $rpc | awk '{print $1}')
  say "$name" "$chain" gov "$gov" "$(ok_eq "$gov" "$ADMIN")"
  say "$name" "$chain" delay "$delay"
  say "$name" "$chain" dappID "$dappID" "$(ok_eq "$dappID" "$expected_dapp_id")"
}

for entry in "Ethereum:mainnet-rpc-url" "Linea:linea-rpc-url"; do
  chain=${entry%%:*}
  rpc=${entry##*:}
  print_gov_client C3Caller $C3CALLER $rpc $chain
  print_gov_client C3UUIDKeeper $UUID_KEEPER $rpc $chain
  print_gov_client C3DAppManager $DAPP_MANAGER $rpc $chain
  print_govern_dapp C3Governor $C3GOV $DAPP_ID_C3GOV $rpc $chain
  print_govern_dapp CTM $CTM $DAPP_ID_CTM $rpc $chain
  echo
done
