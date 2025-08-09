# C3Caller Deployment Guide

This document outlines the complete deployment process for the C3Caller protocol, including contract flattening and deployment steps.

## Overview

The C3Caller protocol consists of upgradeable smart contracts that enable cross-chain communication and governance. The deployment process involves two main steps:

1. **Flattening**: Consolidating all contract dependencies into single files
2. **Deployment**: Deploying the contracts using Foundry scripts

## Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- Access to target blockchain network
- Environment variables configured for RPC endpoints and API keys

## Step 1: Contract Flattening

The first step is to flatten all contracts using the provided bash script. This consolidates all dependencies into single files for easier deployment and verification.

### Run the Flattening Script

```bash
# Make the script executable (if not already)
chmod +x helpers/flatten.sh

# Execute the flattening script
./helpers/flatten.sh
```

## Step 2: Contract Deployment

After flattening, deploy the contracts using the Foundry deployment script.

### Deploy to Local Network (for testing)

```bash
# Deploy to local Anvil instance
forge script script/Deploy.s.sol --rpc-url localhost --broadcast
```

### Deploy to Testnet

```bash
# Example: Deploy to Sepolia testnet
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast
```

### Deploy to Mainnet

```bash
# Example: Deploy to Ethereum mainnet
forge script script/Deploy.s.sol --rpc-url ethereum --broadcast
```

## Deployment Script Details

The deployment script (`script/Deploy.s.sol`) performs the following operations:

### 1. C3UUIDKeeper Deployment
```solidity
C3UUIDKeeperUpgradeable c3UUIDKeeperImpl = new C3UUIDKeeperUpgradeable();
bytes memory c3UUIDKeeperInitData = abi.encodeWithSignature("initialize()");
address c3UUIDKeeper = address(new C3CallerProxy(address(c3UUIDKeeperImpl), c3UUIDKeeperInitData));
```

**Purpose**: Deploys the UUID keeper contract that manages unique identifiers for cross-chain operations.

**Key Features**:
- UUID generation and tracking
- Completion status management
- Replay attack prevention
- Governance-controlled revocation

### 2. C3Caller Deployment
```solidity
C3CallerUpgradeable c3CallerImpl = new C3CallerUpgradeable();
bytes memory c3CallerInitData = abi.encodeWithSignature("initialize(address)", c3UUIDKeeper);
address c3Caller = address(new C3CallerProxy(address(c3CallerImpl), c3CallerInitData));
```

**Purpose**: Deploys the main C3Caller contract that handles cross-chain communication.

**Key Features**:
- Cross-chain call initiation (`c3call`)
- Cross-chain broadcast functionality (`c3broadcast`)
- Cross-chain message execution (`execute`)
- Fallback mechanism for failed calls (`c3Fallback`)
- Pausable functionality for emergency stops
- Governance integration for access control

## Contract Architecture

### Core Components

#### C3CallerUpgradeable
The main contract that serves as the entry point for cross-chain operations. It inherits from:
- `C3GovClientUpgradeable`: Governance functionality
- `OwnableUpgradeable`: Ownership management
- `PausableUpgradeable`: Emergency pause functionality
- `UUPSUpgradeable`: Upgrade mechanism

#### C3UUIDKeeperUpgradeable
Manages unique identifiers for cross-chain operations to prevent replay attacks and ensure uniqueness.

#### C3CallerProxy
ERC1967 proxy contract that delegates calls to the implementation contracts, enabling upgradeable functionality.

### Dependencies

The contracts use the following OpenZeppelin libraries:
- `@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol`
- `@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol`
- `@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol`
- `@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol`

If not already installed as dependencies, run `forge install OpenZeppelin/openzeppelin-contracts && forge install OpenZeppelin/openzeppelin-contracts-upgradeable`

## Environment Configuration

Ensure the following environment variables are set for deployment:

### RPC URLs
```bash
export SEPOLIA_RPC_URL="your_sepolia_rpc_url"
export ARB_SEPOLIA_RPC_URL="your_arbitrum_sepolia_rpc_url"
export BASE_SEPOLIA_RPC_URL="your_base_sepolia_rpc_url"
# ... other network RPC URLs
```

### API Keys (for verification)
```bash
export ETHERSCAN_API_KEY="your_etherscan_api_key"
export ARBISCAN_API_KEY="your_arbiscan_api_key"
export BASE_API_KEY="your_base_api_key"
# ... other explorer API keys
```

## Verification

After deployment, verify the contracts on the respective block explorers:

```bash
# Verify on Etherscan (example for Sepolia)
forge verify-contract <DEPLOYED_ADDRESS> flattened/upgradeable/C3CallerUpgradeable.sol:C3CallerUpgradeable \
    --chain-id 11155111 \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

## Post-Deployment Steps

1. **Verify Contract Addresses**: Confirm all deployed contract addresses are correct
2. **Set Up Governance**: Configure governance parameters and operators
3. **Test Functionality**: Perform test cross-chain operations
4. **Monitor Events**: Set up monitoring for contract events
5. **Document Addresses**: Record all deployed contract addresses for future reference

## Security Considerations

- **Proxy Pattern**: The contracts use the UUPS upgradeable pattern for future upgrades
- **Access Control**: Governance controls are implemented for critical functions
- **Pausable**: Emergency pause functionality is available
- **UUID Management**: Unique identifiers prevent replay attacks
- **Initialization**: Proper initialization ensures contracts are set up correctly

## Troubleshooting

### Common Issues

1. **Flattening Errors**: Ensure all dependencies are properly installed
2. **Deployment Failures**: Check gas limits and RPC connectivity
3. **Verification Issues**: Ensure flattened contracts match deployed bytecode
4. **Initialization Errors**: Verify initialization parameters are correct

### Debug Commands

```bash
# Check contract compilation
forge build

# Test deployment locally
forge script script/Deploy.s.sol --rpc-url localhost --dry-run

# Verify flattened contracts
forge build --force
```

## Network Support

The c3caller contract is deployed to 9 testnets, as configured in `foundry.toml`:

- Arbitrum Sepolia
- Base Sepolia
- Ethereum Sepolia
- OP BNB Testnet
- BSC Testnet
- Avalanche Fuji
- Holesky Testnet
- Soneium Minato
- Scroll Sepolia

They are all deployed to 0x9e0625366F7d85A174a59b1a5D2e44F1492a9cBB.

Each network has its own RPC endpoint and block explorer configuration for deployment and verification. 
