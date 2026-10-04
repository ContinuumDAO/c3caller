#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

run() {
  local title="$1" script="$2"
  ctitle "$title"
  bash "$SCRIPT_DIR/$script"
  echo
}

run "Gov and paused" check-gov-and-paused.sh
run "Implementations" check-implementations.sh
run "Wiring" check-wiring.sh
run "C3Caller peers" check-peers-c3caller.sh
run "C3Governor peers" check-peers-c3governor.sh
run "CTM peers" check-peers-ctm.sh
run "DApp" check-dapp.sh
run "Fee config" check-fee-config.sh
run "CTM supply" check-ctm-supply.sh
