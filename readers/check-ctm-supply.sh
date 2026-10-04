#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

globalEth=$(cast call $CTM "globalSupply()(uint256)" --rpc-url mainnet-rpc-url | awk '{print $1}')
localEth=$(cast call $CTM "totalSupply()(uint256)" --rpc-url mainnet-rpc-url | awk '{print $1}')
localLinea=$(cast call $CTM "totalSupply()(uint256)" --rpc-url linea-rpc-url | awk '{print $1}')
localSum=$(python3 -c "print(int('$localEth') + int('$localLinea'))")

say CTM Ethereum globalSupply "$globalEth" "$(ok_nonzero "$globalEth")"
say CTM Ethereum totalSupply "$localEth"
say CTM Linea totalSupply "$localLinea"
echo
printf '%s local %s (%s + %s): %s, %s\n' \
  "$(cname CTM)" \
  "$(cfield "totalSupply sum")" \
  "$(cchain Ethereum)" \
  "$(cchain Linea)" \
  "$(cval "$localSum")" \
  "$(ok_eq "$localSum" "$globalEth")"
