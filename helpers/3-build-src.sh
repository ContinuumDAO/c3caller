#!/bin/bash

echo -e "\n🔨 Compiling src/C3Caller.sol..."
forge build ./src/C3Caller.sol
echo -e "Compiling  src/dapp..."
forge build ./src/dapp/
echo -e "🔨 Compiling src/gov..."
forge build ./src/gov/
echo -e "🔨 Compiling src/token..."
forge build ./src/token/
echo -e "🔨 Compiling src/upgradeable..."
forge build ./src/upgradeable/
echo -e "🔨 Compiling src/utils..."
forge build ./src/utils/
echo -e "🔨 Compiling src/uuid..."
forge build ./src/uuid/
