#!/bin/bash

# remove old flattened files
rm -r flattened/

# create folders
mkdir -p flattened/
mkdir -p flattened/dapp/
mkdir -p flattened/gov/
mkdir -p flattened/upgradeable/
mkdir -p flattened/upgradeable/dapp/
mkdir -p flattened/upgradeable/gov/
mkdir -p flattened/upgradeable/uuid/
mkdir -p flattened/utils/
mkdir -p flattened/uuid/

# .
forge flatten src/C3Caller.sol --output flattened/C3Caller.sol

# dapp
forge flatten src/dapp/C3CallerDApp.sol --output flattened/dapp/C3CallerDApp.sol
forge flatten src/dapp/C3DAppManager.sol --output flattened/dapp/C3DAppManager.sol

# gov
forge flatten src/gov/C3GovClient.sol --output flattened/gov/C3GovClient.sol
forge flatten src/gov/C3GovernDApp.sol --output flattened/gov/C3GovernDApp.sol
forge flatten src/gov/C3Governor.sol --output flattened/gov/C3Governor.sol

# upgradeable
forge flatten src/upgradeable/C3CallerUpgradeable.sol --output flattened/upgradeable/C3CallerUpgradeable.sol

# upgradeable/dapp
forge flatten src/upgradeable/dapp/C3CallerDAppUpgradeable.sol --output flattened/upgradeable/dapp/C3CallerDAppUpgradeable.sol
forge flatten src/upgradeable/dapp/C3DAppManagerUpgradeable.sol --output flattened/upgradeable/dapp/C3DAppManagerUpgradeable.sol

# upgradeable/gov
forge flatten src/upgradeable/gov/C3GovClientUpgradeable.sol --output flattened/upgradeable/gov/C3GovClientUpgradeable.sol
forge flatten src/upgradeable/gov/C3GovernDAppUpgradeable.sol --output flattened/upgradeable/gov/C3GovernDAppUpgradeable.sol
forge flatten src/upgradeable/gov/C3GovernorUpgradeable.sol --output flattened/upgradeable/gov/C3GovernorUpgradeable.sol

# upgradeable/uuid
forge flatten src/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol --output flattened/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol

# utils
forge flatten src/utils/C3CallerProxy.sol --output flattened/utils/C3CallerProxy.sol
forge flatten src/utils/C3CallerUtils.sol --output flattened/utils/C3CallerUtils.sol
forge flatten src/utils/TestERC20.sol --output flattened/utils/TestERC20.sol

# uuid
forge flatten src/uuid/C3UUIDKeeper.sol --output flattened/uuid/C3UUIDKeeper.sol
