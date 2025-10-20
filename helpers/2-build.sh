#!/bin/bash

echo -e "\n🔨 Compiling build/C3Caller.sol..."
forge build ./build/C3Caller.sol
echo -e "🔨 Compiling build/dapp..."
forge build ./build/dapp/
echo -e "🔨 Compiling build/gov..."
forge build ./build/gov/
echo -e "🔨 Compiling build/upgradeable..."
forge build ./build/upgradeable/
echo -e "🔨 Compiling build/utils..."
forge build ./build/utils/
echo -e "🔨 Compiling build/uuid..."
forge build ./build/uuid/
