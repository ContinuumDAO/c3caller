#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_peers() {
  local rpc="$1" chain="$2"
  peer1=$(cast call $C3GOV "peer(string)(string)" 1 --rpc-url $rpc | tr -d '"')
  peer59144=$(cast call $C3GOV "peer(string)(string)" 59144 --rpc-url $rpc | tr -d '"')
  say C3Governor "$chain" "peer on chain ID 1" "$peer1" "$(ok_eq "$peer1" "$C3GOV")"
  say C3Governor "$chain" "peer on chain ID 59144" "$peer59144" "$(ok_eq "$peer59144" "$C3GOV")"
}

print_peers mainnet-rpc-url Ethereum
print_peers linea-rpc-url Linea
