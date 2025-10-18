#!/bin/bash

# remove old build files
rm -r build/

# create folders
mkdir -p build/
mkdir -p build/dapp/
mkdir -p build/gov/
mkdir -p build/upgradeable/
mkdir -p build/upgradeable/dapp/
mkdir -p build/upgradeable/gov/
mkdir -p build/upgradeable/uuid/
mkdir -p build/utils/
mkdir -p build/uuid/

echo -e "\n📄 Flattening src/ to build/..."

# .
forge flatten src/C3Caller.sol --output build/C3Caller.sol

# dapp
forge flatten src/dapp/C3CallerDApp.sol --output build/dapp/C3CallerDApp.sol
forge flatten src/dapp/C3DAppManager.sol --output build/dapp/C3DAppManager.sol

# gov
forge flatten src/gov/C3GovClient.sol --output build/gov/C3GovClient.sol
forge flatten src/gov/C3GovernDApp.sol --output build/gov/C3GovernDApp.sol
forge flatten src/gov/C3Governor.sol --output build/gov/C3Governor.sol

# upgradeable
forge flatten src/upgradeable/C3CallerUpgradeable.sol --output build/upgradeable/C3CallerUpgradeable.sol

# upgradeable/dapp
forge flatten src/upgradeable/dapp/C3CallerDAppUpgradeable.sol --output build/upgradeable/dapp/C3CallerDAppUpgradeable.sol
forge flatten src/upgradeable/dapp/C3DAppManagerUpgradeable.sol --output build/upgradeable/dapp/C3DAppManagerUpgradeable.sol

# upgradeable/gov
forge flatten src/upgradeable/gov/C3GovClientUpgradeable.sol --output build/upgradeable/gov/C3GovClientUpgradeable.sol
forge flatten src/upgradeable/gov/C3GovernDAppUpgradeable.sol --output build/upgradeable/gov/C3GovernDAppUpgradeable.sol
forge flatten src/upgradeable/gov/C3GovernorUpgradeable.sol --output build/upgradeable/gov/C3GovernorUpgradeable.sol

# upgradeable/uuid
forge flatten src/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol --output build/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol

# utils
forge flatten src/utils/C3CallerProxy.sol --output build/utils/C3CallerProxy.sol
forge flatten src/utils/C3CallerUtils.sol --output build/utils/C3CallerUtils.sol

# uuid
forge flatten src/uuid/C3UUIDKeeper.sol --output build/uuid/C3UUIDKeeper.sol
