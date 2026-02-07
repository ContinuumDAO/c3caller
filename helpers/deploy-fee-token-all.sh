#!/bin/bash
# Deploy fee token (DeployFeeToken.s.sol / TestUSD) on every chain.
# Writes fee-token.json with chainId, contract address, and error (if failed).
# Uses same gas parameters as protocol deploy scripts: --legacy for metis/lightlink, --gas-estimate-multiplier 600 for cronos-zkevm.
# No verification.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

if [ $# -lt 2 ]; then
    echo "Usage: $0 <ACCOUNT> <PASSWORD_FILE>"
    echo "Example: $0 0 /path/to/password.txt"
    exit 1
fi

ACCOUNT=$1
PASSWORD_FILE=$2
BROADCAST_DIR="$PROJECT_ROOT/broadcast/DeployFeeToken.s.sol"
RESULTS_FILE="$PROJECT_ROOT/fee-token.json"

# Chain list: slug (rpc-url name), chain_id, optional gas flags (--legacy or --gas-estimate-multiplier 600)
# Same order as helpers/deploy/all.sh
CHAINS=(
    "bsc-testnet:97"
    "soneium-minato-testnet:1946"
    "opbnb-testnet:5611"
    "plume-testnet:98867"
    "base-sepolia:84532"
    "arbitrum-sepolia:421614"
    "scroll-sepolia:534351"
    "sonic-blaze:57054"
    "amoy:80002"
    "optimism-sepolia:11155420"
    "sepolia:11155111"
    "fuji:43113"
    "linea-sepolia:59141"
    "mantle-sepolia:5003"
    "zksync-testnet:300"
    "celo-sepolia:11142220"
    "hoodi:560048"
    "monad-testnet:10143"
    "core-testnet:1114"
    "rsk-testnet:31"
    "bitlayer-testnet:200810:--legacy"
    "lens-testnet:37111"
    "manta-sepolia:3441006"
    "abstract-testnet:11124"
    "mantra-testnet:5887"
    "shape-sepolia:11011"
    # tempo-moderato:42431 — We use standard forge (no --fee-token). Tempo infers fee token: account default or pathUSD. If deploy fails despite pathUSD balance, try: (1) Tempo Foundry fork: foundryup -n tempo, then add --fee-token 0x20c0000000000000000000000000000000000000 for this chain; or (2) Fee AMM liquidity (pathUSD→validator alphaUSD) may be exhausted — retry later.
    "tempo-moderato:42431"
    "berachain-bepolia:80069"
    "cronos-zkevm-testnet:240:--gas-estimate-multiplier 600"
    "arc-testnet:5042002"
    "boba-sepolia:28882"
    "citrea-testnet:5115"
    "metis-sepolia:59902:--legacy"
    "mode-testnet:919"
    "ink-sepolia:763373"
    "world-chain-sepolia:4801"
    "polynomial-sepolia:80008"
    "bob-sepolia:808813"
    "kiteai-testnet:2368"
    "lightlink-pegasus-testnet:1891:--legacy"
)

RESULTS=()

for entry in "${CHAINS[@]}"; do
    IFS=':' read -r slug chain_id gas_flags <<< "$entry"
    # gas_flags may be empty
    rpc_url="${slug}-rpc-url"
    echo "=== $slug (chain $chain_id) ==="

    run_err=$(mktemp)

    set +e
    # Let forge stdout through so user sees progress (simulation, broadcast, tx hashes)
    forge script script/DeployFeeToken.s.sol \
        --tc DeployFeeToken \
        --account "$ACCOUNT" \
        --password-file "$PASSWORD_FILE" \
        --rpc-url "$rpc_url" \
        --chain-id "$chain_id" \
        --slow \
        $gas_flags \
        --broadcast \
        2> "$run_err"
    exitcode=$?
    set -e

    if [ $exitcode -eq 0 ]; then
        run_file="$BROADCAST_DIR/$chain_id/run-latest.json"
        if [ -f "$run_file" ]; then
            addr=$(jq -r '.transactions[] | select(.transactionType == "CREATE") | .contractAddress' "$run_file" | head -n1)
            if [ -n "$addr" ] && [ "$addr" != "null" ]; then
                RESULTS+=("$(jq -n --argjson cid "$chain_id" --arg addr "$addr" -c '{chainId: $cid, address: $addr, error: null}')")
                echo "  Deployed: $addr"
            else
                RESULTS+=("$(jq -n --argjson cid "$chain_id" -c '{chainId: $cid, address: null, error: "No CREATE transaction in broadcast JSON"}')")
                echo "  No CREATE in broadcast"
            fi
        else
            RESULTS+=("$(jq -n --argjson cid "$chain_id" -c '{chainId: $cid, address: null, error: "Broadcast file not found"}')")
            echo "  Broadcast file not found"
        fi
    else
        err_msg=$(tail -15 "$run_err" | sed ':a;N;$!ba;s/\n/ /g' | head -c 400)
        [ -z "$err_msg" ] && err_msg="Deployment failed (exit $exitcode)"
        RESULTS+=("$(jq -n --argjson cid "$chain_id" --arg err "$err_msg" -c '{chainId: $cid, address: null, error: $err}')")
        echo "  Failed: $err_msg"
    fi

    rm -f "$run_err"
done

# Write JSON array
echo "[" > "$RESULTS_FILE"
first=true
for r in "${RESULTS[@]}"; do
    $first || echo "," >> "$RESULTS_FILE"
    first=false
    echo -n "  $r" >> "$RESULTS_FILE"
done
echo -e "\n]" >> "$RESULTS_FILE"

echo ""
echo "Results written to $RESULTS_FILE"

# Merge new fee token addresses into deployments.toml (fee_token + [[chainId.fee_tokens]])
echo "Merging fee tokens into deployments.toml..."
(cd "$PROJECT_ROOT" && node js-helpers/merge-fee-token-json-to-deployments.js)
