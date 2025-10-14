#!/bin/bash

echo -e "\n🔨 Compiling test/C3Caller.t.sol..."
forge build ./test/C3Caller.t.sol
echo -e "🔨 Compiling test/dapp..."
forge build ./test/dapp/
echo -e "🔨 Compiling test/gov..."
forge build ./test/gov/
echo -e "🔨 Compiling test/helpers..."
forge build ./test/helpers/
echo -e "🔨 Compiling test/upgradeable..."
forge build ./test/upgradeable/
echo -e "🔨 Compiling test/uuid..."
forge build ./test/uuid/
