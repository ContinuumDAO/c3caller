ZERO_ADDR=0x0000000000000000000000000000000000000000
ADMIN=0xccc435AaBc481D4Af9da51E51Eb2a383Bce6791F
MPC=0xccc435AaBc481D4Af9da51E51Eb2a383Bce6791F
C3CALLER=0x2f925D6512b2BbB00f5a36d8B18E01fcf35F7Dc7
UUID_KEEPER=0xE605C920c942EA4E807a688c554bf83C59D4DB41
DAPP_MANAGER=0x9e0625366F7d85A174a59b1a5D2e44F1492a9cBB
C3GOV=0x58B610a359c870E0fc941139821a51F5aa23f14E
CTM=0x7581696b0ED142f6534E5797baaABBb9a1b27086
C3CALLER_IMPL=0x0C746CF1cadd15f800b7D64c3c023D690d6a271a
UUID_KEEPER_IMPL=0x849a78D9e70D2428c9531981f6F3fcEcB378A78f
DAPP_MANAGER_IMPL=0x7A43576Da6A2f738F724747697Cd2fD2424F0C7D
C3GOV_IMPL=0x430e19F6BdeeC59093AaE877aF874EEf6D7d943e
USDC_ETH=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDC_LINEA=0x176211869cA2b568f2A7D4EE941E073a821EE1ff
DAPP_ID_CTM=26243786160252405427302909576549313777876500874080323496247859302443561356480
DAPP_ID_C3GOV=54841553903020218527075297192242923310195705512185382121058570035346596394010
DAPP_KEY_CTM=v1.continuumdao.ctm
DAPP_KEY_C3GOV=v1.continuumdao.c3governor_u
METADATA_C3GOV_ETH='{"version":1,name:"C3Governor","description":"C3Governor on Ethereum","email":"continuumdao@proton.me","url":"continuumdao.org"}'
METADATA_CTM_ETH='{"version":2,name:"CTM","description":"CTM on Ethereum","email":"continuumdao@proton.me","url":"continuumdao.org"}'
METADATA_C3GOV_LINEA='{"version":1,name:"C3Governor","description":"C3Governor on Linea","email":"continuumdao@proton.me","url":"continuumdao.org"}'
METADATA_CTM_LINEA='{"version":2,name:"CTM","description":"CTM on Linea","email":"continuumdao@proton.me","url":"continuumdao.org"}'

if [ -t 1 ]; then
  C_OK=$(printf '\033[92m')
  C_BAD=$(printf '\033[91m')
  C_WARN=$(printf '\033[93m')
  C_NAME=$(printf '\033[96m')
  C_CHAIN=$(printf '\033[93m')
  C_FIELD=$(printf '\033[94m')
  C_ADDR=$(printf '\033[95m')
  C_VAL=$(printf '\033[97m')
  C_TITLE=$(printf '\033[1;36m')
  C_MUTED=$(printf '\033[2m')
  C_RESET=$(printf '\033[0m')
else
  C_OK=
  C_BAD=
  C_WARN=
  C_NAME=
  C_CHAIN=
  C_FIELD=
  C_ADDR=
  C_VAL=
  C_TITLE=
  C_MUTED=
  C_RESET=
fi

paint() {
  printf '%s%s%s' "$1" "$2" "$C_RESET"
}

cname() { paint "$C_NAME" "$1"; }
cchain() { paint "$C_CHAIN" "$1"; }
cfield() { paint "$C_FIELD" "$1"; }
caddr() { paint "$C_ADDR" "$1"; }
cval() {
  local v="$1"
  case "$v" in
    0x*|0X*) paint "$C_ADDR" "$v" ;;
    true|Active) paint "$C_OK" "$v" ;;
    false) paint "$C_MUTED" "$v" ;;
    Dormant) paint "$C_WARN" "$v" ;;
    Suspended|Deprecated) paint "$C_BAD" "$v" ;;
    *) paint "$C_VAL" "$v" ;;
  esac
}

ctitle() {
  printf '%s=== %s ===%s\n' "$C_TITLE" "$1" "$C_RESET"
}

say() {
  local entity="$1" chain="$2" field="$3" value="$4"
  local status="${5:-}"
  if [ -n "$status" ] && [ -z "$value" ]; then
    printf '%s on %s, %s: %s\n' "$(cname "$entity")" "$(cchain "$chain")" "$(cfield "$field")" "$status"
  elif [ -n "$status" ]; then
    printf '%s on %s, %s: %s, %s\n' "$(cname "$entity")" "$(cchain "$chain")" "$(cfield "$field")" "$(cval "$value")" "$status"
  else
    printf '%s on %s, %s: %s\n' "$(cname "$entity")" "$(cchain "$chain")" "$(cfield "$field")" "$(cval "$value")"
  fi
}

_status() {
  if [ "$1" = ok ]; then
    printf '%sok%s\n' "$C_OK" "$C_RESET"
  else
    printf '%sMISMATCH%s\n' "$C_BAD" "$C_RESET"
  fi
}

_norm() {
  printf '%s' "$1" | sed 's/ \[[^]]*\]//g' | tr '[:upper:]' '[:lower:]' | tr -d '"[] \t\r\n'
}

ok_eq() {
  if [ "$(_norm "$1")" = "$(_norm "$2")" ]; then
    _status ok
  else
    _status MISMATCH
  fi
}

ok_true() {
  case "$(_norm "$1")" in
    true|1) _status ok ;;
    *) _status MISMATCH ;;
  esac
}

ok_false() {
  case "$(_norm "$1")" in
    false|0) _status ok ;;
    *) _status MISMATCH ;;
  esac
}

ok_nonzero() {
  local n
  n=$(_norm "$1")
  if [ -n "$n" ] && [ "$n" != "0" ]; then
    _status ok
  else
    _status MISMATCH
  fi
}

ok_contains() {
  local hay needle
  hay=$(_norm "$1")
  needle=$(_norm "$2")
  case "$hay" in
    *"$needle"*) _status ok ;;
    *) _status MISMATCH ;;
  esac
}

ok_has_id() {
  local needle=$1 id
  shift
  for id in $*; do
    if [ "$id" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}
