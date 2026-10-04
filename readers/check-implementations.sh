#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_impl() {
  local name="$1" proxy="$2" expected="$3" rpc="$4" chain="$5"
  impl=$(cast call $proxy "getImplementation()(address)" --rpc-url $rpc)
  say "$name" "$chain" implementation "$impl" "$(ok_eq "$impl" "$expected")"
}

for entry in "Ethereum:mainnet-rpc-url" "Linea:linea-rpc-url"; do
  chain=${entry%%:*}
  rpc=${entry##*:}
  print_impl C3Caller $C3CALLER $C3CALLER_IMPL $rpc $chain
  print_impl C3UUIDKeeper $UUID_KEEPER $UUID_KEEPER_IMPL $rpc $chain
  print_impl C3DAppManager $DAPP_MANAGER $DAPP_MANAGER_IMPL $rpc $chain
  print_impl C3Governor $C3GOV $C3GOV_IMPL $rpc $chain
  echo
done
