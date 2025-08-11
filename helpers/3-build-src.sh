#!/bin/bash

echo -e "\nBuilding src/C3Caller.sol..."
forge build ./src/C3Caller.sol
echo -e "\nBuilding src/dapp..."
forge build ./src/dapp/
echo -e "\nBuilding src/gov..."
forge build ./src/gov/
echo -e "\nBuilding src/upgradeable..."
forge build ./src/upgradeable/
echo -e "\nBuilding src/utils..."
forge build ./src/utils/
echo -e "\nBuilding src/uuid..."
forge build ./src/uuid/
