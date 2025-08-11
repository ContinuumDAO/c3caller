# Deployment Guide for C3Caller

## Introduction

Dependencies: foundry

Verification: An Etherscan API V2 key,
see [here](https://docs.etherscan.io/etherscan-v2/v2-quickstart).

For security in deployment, this guide assumes that you are using an account
saved in a keystore, and that you have a password file saved locally.

Use a fresh wallet and ensure you have plenty of gas for deployment and
configuration.

See [Foundry keystores](https://getfoundry.sh/cast/reference/wallet).

## .env file

Modify .env for the following structure. To get DApp IDs, go to
the [DApp Registry](https://c3caller.continuumdao.org).

```
# RPCs
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
BASE_SEPOLIA_RPC_URL=https://base-sepolia-rpc.publicnode.com
BSC_TESTNET_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545/
AVALANCHE_FUJI_RPC_URL=https://api.avax-test.network/ext/bc/C/rpc
OPBNB_TESTNET_RPC_URL=https://opbnb-testnet-rpc.publicnode.com
HOLESKY_RPC_URL=https://holesky.gateway.tenderly.co
SCROLL_SEPOLIA_RPC_URL=https://sepolia-rpc.scroll.io
SONEIUM_MINATO_RPC_URL=https://rpc.minato.soneium.org/

# Etherscan API Key V2
ETHERSCAN_API_KEY=
```

## Make Scripts Executable

```bash
chmod +x helpers/[0-9]*
chmod +x helpers/deploy/*
```

## Flatten the source directory

This is required for single-file verification on chains that do not support Etherscan and to facilitate remedial manual verification.

```bash
./helpers/0-flatten.sh
```

## Compilation

Use the compilation script to compile the flattened source code and scripts.

```bash
./helpers/1-clean.sh
./helpers/2-build-flattened.sh
./helpers/5-build-script.sh
```

## Deploy Contracts

Run each of the following scripts to deploy. This will first execute a simulation, then allow you elect to deploy all contracts to the given network (broadcast) and verify the contracts on Etherscan if possible.

```bash
./helpers/deploy/arbitrum-sepolia.sh <DEPLOYER> <PATH_TO_PASSWORD_FILE>
./helpers/deploy/avalanche-fuji.sh <DEPLOYER> <PATH_TO_PASSWORD_FILE>
./helpers/deploy/base-sepolia.sh <DEPLOYER> <PATH_TO_PASSWORD_FILE>
./helpers/deploy/bsc-testnet.sh <DEPLOYER> <PATH_TO_PASSWORD_FILE>
./helpers/deploy/holesky.sh <DEPLOYER> <PATH_TO_PASSWORD_FILE>
./helpers/deploy/opbnb-testnet.sh <DEPLOYER> <PATH_TO_PASSWORD_FILE>
./helpers/deploy/scroll-sepolia.sh <DEPLOYER> <PATH_TO_PASSWORD_FILE>
./helpers/deploy/sepolia.sh <DEPLOYER> <PATH_TO_PASSWORD_FILE>
./helpers/deploy/soneium-minato-testnet.sh <DEPLOYER> <PATH_TO_PASSWORD_FILE>
```

All contracts are now deployed and initialized; their addresses are accessible in `broadcast/<chain-id>/run-latest.json`.

All contracts have an upgradeable version (ERC1967 Universal Upgradeable Proxy
Standard). This is the version deployed by default.

Note: For the proxies, go to Etherscan and select
"Contract > More Options > Is this a proxy?" to link its implementation contract.

## Write Deployed Contracts to File

Run the JS helper found in `js-helpers/list-contract-addresses.js` to generate a
JSON file containing latest deployed contract addresses.

```bash
node js-helpers/list-contract-addresses.js
```

## Complete

The contracts are now deployed and verified on all test networks.

# Appendices

## Appendix I: Network names available in Forge

These are the chain names that can be used with the `--chain` flag in Foundry.

### Current Deployed Testnets
- **sepolia** (Ethereum Sepolia)
- **holesky** (Ethereum Holesky)
- **arbitrum-sepolia**
- **base-sepolia**
- **bsc-testnet**
- **avalanche-fuji**
- **scroll-sepolia**
- **opbnb-testnet**
- **soneium-minato-testnet**

### Mainnet Networks
- mainnet
- ethereum

### Testnet Networks
- goerli

### Layer 2 Networks
- arbitrum
- arbitrum-goerli
- base
- base-goerli
- optimism
- optimism-sepolia
- optimism-goerli
- polygon
- polygon-mumbai
- polygon-zkevm
- polygon-zkevm-testnet

### Other Major Networks
- bsc
- avalanche
- fantom
- fantom-testnet
- cronos
- cronos-testnet
- gnosis
- gnosis-chiado

### Rollups and Specialized Networks
- scroll
- linea
- linea-sepolia
- mantle
- mantle-sepolia
- zksync
- zksync-sepolia
- starknet
- starknet-sepolia