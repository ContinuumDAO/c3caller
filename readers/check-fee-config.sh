#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_fee() {
  local token="$1" rpc="$2" chain="$3"

  enabled=$(cast call $DAPP_MANAGER "feeCurrencies(address)(bool)" $token --rpc-url $rpc)
  perByte=$(cast call $DAPP_MANAGER "payloadPerByteFee(address)(uint256)" $token --rpc-url $rpc)
  perGas=$(cast call $DAPP_MANAGER "gasPerEtherFee(address)(uint256)" $token --rpc-url $rpc)
  minDeposit=$(cast call $DAPP_MANAGER "feeMinimumDeposit(address)(uint256)" $token --rpc-url $rpc)
  cumulative=$(cast call $DAPP_MANAGER "cumulativeFees(address)(uint256)" $token --rpc-url $rpc)

  say "Fee token $(caddr "$token")" "$chain" feeCurrencies "$enabled" "$(ok_true "$enabled")"
  say "Fee token $(caddr "$token")" "$chain" payloadPerByteFee "$perByte" "$(ok_nonzero "$perByte")"
  say "Fee token $(caddr "$token")" "$chain" gasPerEtherFee "$perGas" "$(ok_nonzero "$perGas")"
  say "Fee token $(caddr "$token")" "$chain" feeMinimumDeposit "$minDeposit"
  say "Fee token $(caddr "$token")" "$chain" cumulativeFees "$cumulative"
}

print_fee $USDC_ETH mainnet-rpc-url Ethereum
echo
print_fee $USDC_LINEA linea-rpc-url Linea
