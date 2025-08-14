# C3Caller (Continuum Cross-Chain Caller)

:satellite: A smart contract suite for arbitrary execution of data across
cross-chain DApps using the ContinuumDAO MPC network.

# Table of Contents

- [Project Structure](#project-structure)
- [API Reference](#api-reference)
- [Installation](#installation)
- [Integration](#integration-into-your-dapp)
- [Deployment](docs/DEPLOYMENT.md)

# Project Structure

src/\
├── C3Caller.sol\
├── dapp\
│   ├── C3CallerDapp.sol\
│   └── C3DappManager.sol\
├── gov\
│   ├── C3GovClient.sol\
│   ├── C3GovernDapp.sol\
│   └── C3Governor.sol\
├── upgradeable\
│   ├── C3CallerUpgradeable.sol\
│   ├── dapp\
│   │   ├── C3CallerDappUpgradeable.sol\
│   │   └── C3DappManagerUpgradeable.sol\
│   ├── gov\
│   │   ├── C3GovClientUpgradeable.sol\
│   │   ├── C3GovernDappUpgradeable.sol\
│   │   └── C3GovernorUpgradeable.sol\
│   └── uuid\
│       └── C3UUIDKeeperUpgradeable.sol\
├── utils\
│   ├── C3CallerProxy.sol\
│   └── C3CallerUtils.sol\
└── uuid\
    └── C3UUIDKeeper.sol

# API Reference

## Core Utility

- [C3Caller](docs/C3Caller.md)
- [C3UUIDKeeper](docs/uuid/C3UUIDKeeper.md)
- [C3GovClient](docs/gov/C3GovClient.md)
- [C3DAppManager](docs/dapp/C3DAppManager.md)

## User Integrations

- [C3CallerDApp](docs/dapp/C3CallerDApp.md)
- [C3GovernDApp](docs/gov/C3GovernDApp.md)
- [C3Governor](docs/gov/C3Governor.md)

## Upgrades

- [C3Upgrades](docs/upgradeable/C3Upgrades.md)

# Installation

## Dependencies

[Foundry](https://getfoundry.sh/) is currently supported, or any smart contract
development framework that supports git submodules.

Install C3Caller to access the smart contracts and implement a C3CallerDApp:

```bash
forge install ContinuumDAO/c3caller
```

Example entry in `remappings.txt`:

```
@c3caller/=lib/c3caller/src/
```

# Integration into your DApp

Inherit from `C3CallerDApp` and implement the required functions to make it C3Caller compliant:

```solidity
import { C3CallerDApp } from "@c3caller/dapp/C3CallerDApp.sol";

contract MyDApp is C3CallerDApp {

    error CrossChainTransferFailed();

    // The address of the corresponding contract on another chain that will be in communication with this one.
    // It is a string type to accommodate networks that use some other form of account, other than 20-byte hex.
    mapping (string => string) public peers;

    mapping (address => bool) public isMPC;
    mapping (address => uint256) public failedTransfer;

    // Here, we initialize the DApp. Initialize C3CallerDApp with the c3caller endpoint and your DApp ID.
    constructor (address _endpoint, uint256 _dappID, address _mpc, string[] memory _chainIDs, string[] memory _peers)
        C3CallerDApp(_endpoint, _dappID)
    {
        isMPC[_mpc] = true;

        // Here tell this contract the addresses of the contracts that are deployed on other networks that we wish to
        // communicate with via c3caller.
        for (uint8 i = 0; i < _chainIDs.length; i++) {
            peers[_chainIDs[i]] = _peers[i];
        }
    }

    // Override this function to decide who can execute functions in your DApp (for incoming cross-chain calls)
    // Set it to allow the valid MPC address on the network in question to allow cross-chain execution from other chains
    function isValidSender(address _txSender) external view virtual override returns (bool) {
        return isMPC[_txSender];
    }

    // Override this function to decide what happens when a cross-chain call reverted on the target network.
    // In this example, we check for a known error on the target network and act accordingly.
    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason)
        internal
        virtual
        override
        returns (bool)
    {
        if (_selector == CrossChainTransferFailed.selector) {
            (address _recipient, uint256 _amount) = abi.decode(_data, (address, uint256));
            // A cross-chain transfer has failed. Compensate the would-be recipient locally
            failedTransfer[_recipient] += _amount;
        }
        return true;
    }

    // Here we have a function that initiates a cross-chain call. It provides the address of the contract on the
    // target network, based on the given chain ID.
    function transferCrossChain(string memory _targetChainID, address _recipient, uint256 _amount) external {
        bytes memory _data = abi.encodeWithSignature("receiveCrossChain(address,uint256)", (_recipient, _amount));
        string memory _targetNetworkDAppAddress = peers[_targetChainID];
        _c3call(_targetNetworkDAppAddress, _chainID, _data);
    }

    // This function can be executed by `transferCrossChain` that was called from another network.
    // Note the `onlyCaller` modifier to ensure only the C3Caller contract (and thus the MPC network) can call this.
    function receiveCrossChain(address _recipient, uint256 _amount) external onlyCaller {
        tokenXYZ.transfer(_recipient, _amount);
    }
}
```