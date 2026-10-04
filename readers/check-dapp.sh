#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

status_label() {
  case $1 in
    0) echo Active ;;
    1) echo Dormant ;;
    2) echo Suspended ;;
    3) echo Deprecated ;;
    *) echo "Unknown($1)" ;;
  esac
}

print_metadata() {
  python3 - "$1" "$C_FIELD" "$C_VAL" "$C_RESET" <<'PY'
import re, sys

raw = sys.argv[1].strip()
c_field, c_val, c_reset = sys.argv[2], sys.argv[3], sys.argv[4]
if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "\"'":
    raw = raw[1:-1]
raw = bytes(raw, "utf-8").decode("unicode_escape")
body = raw[1:-1] if raw.startswith("{") and raw.endswith("}") else raw
pairs = re.findall(r'"?(\w+)"?\s*:\s*(?:"([^"]*)"|([0-9]+))', body)
for key, sval, nval in pairs:
    value = sval if sval else nval
    print(f"  {c_field}{key}{c_reset}: {c_val}{value}{c_reset}")
PY
}

print_dapp() {
  local name="$1"
  local dappID="$2"
  local dappKey="$3"
  local dappAddr="$4"
  local feeToken="$5"
  local metadata="$6"
  local rpc="$7"
  local chain="$8"

  derived=$(cast call $DAPP_MANAGER "deriveDAppID(address,string)(uint256)" $ADMIN "$dappKey" --rpc-url $rpc | awk '{print $1}')
  say "$name" "$chain" dappID "$derived" "$(ok_eq "$derived" "$dappID")"

  status=$(cast call $DAPP_MANAGER "dappStatus(uint256)(uint8)" $dappID --rpc-url $rpc)
  reason=$(cast call $DAPP_MANAGER "statusReason(uint256)(string)" $dappID --rpc-url $rpc | tr -d '"')
  say "$name" "$chain" status "$(status_label $status)" "$(ok_eq "$status" 0)"
  say "$name" "$chain" statusReason "$reason" "$(ok_eq "$reason" "")"

  mapfile -t cfg < <(cast call $DAPP_MANAGER "dappConfig(uint256)(address,address,uint256,uint256,string)" $dappID --rpc-url $rpc)
  admin=${cfg[0]}
  cfgFeeToken=$(echo "${cfg[1]}" | tr -d '"')
  discount=${cfg[2]}
  lastUpdated=${cfg[3]}
  onchainMetadata=${cfg[4]}
  say "$name" "$chain" admin "$admin" "$(ok_eq "$admin" "$ADMIN")"
  say "$name" "$chain" feeToken "$cfgFeeToken" "$(ok_eq "$cfgFeeToken" "$feeToken")"
  say "$name" "$chain" discount "$discount" "$(ok_eq "$discount" 0)"
  say "$name" "$chain" lastUpdated "$lastUpdated"
  say "$name" "$chain" metadata "" "$(ok_eq "${onchainMetadata//\\/}" "$metadata")"
  print_metadata "$onchainMetadata"

  addrs=$(cast call $DAPP_MANAGER "getAllDAppAddrs(uint256)(address[])" $dappID --rpc-url $rpc | tr -d '[] ')
  say "$name" "$chain" dappAddrs "$addrs" "$(ok_contains "$addrs" "$dappAddr")"

  mpcs=$(cast call $DAPP_MANAGER "getAllDAppMPCAddrs(uint256)(address[])" $dappID --rpc-url $rpc | tr -d '[] ')
  if [ -z "$(_norm "$mpcs")" ]; then
    mpc_status=$(_status ok)
  else
    mpc_status=$(ok_contains "$mpcs" "$MPC")
  fi
  say "$name" "$chain" dappMPCAddrs "$mpcs" "$mpc_status"

  stake=$(cast call $DAPP_MANAGER "dappStakePool(uint256,address)(uint256)" $dappID $feeToken --rpc-url $rpc)
  printf '%s on %s, %s(%s): %s\n' \
    "$(cname "$name")" \
    "$(cchain "$chain")" \
    "$(cfield dappStakePool)" \
    "$(caddr "$feeToken")" \
    "$(cval "$stake")"
}

print_dapp CTM $DAPP_ID_CTM "$DAPP_KEY_CTM" $CTM $USDC_ETH "$METADATA_CTM_ETH" mainnet-rpc-url Ethereum
echo
print_dapp C3Governor $DAPP_ID_C3GOV "$DAPP_KEY_C3GOV" $C3GOV $USDC_ETH "$METADATA_C3GOV_ETH" mainnet-rpc-url Ethereum
echo
print_dapp CTM $DAPP_ID_CTM "$DAPP_KEY_CTM" $CTM $USDC_LINEA "$METADATA_CTM_LINEA" linea-rpc-url Linea
echo
print_dapp C3Governor $DAPP_ID_C3GOV "$DAPP_KEY_C3GOV" $C3GOV $USDC_LINEA "$METADATA_C3GOV_LINEA" linea-rpc-url Linea
