#!/bin/bash

forge clean

# flattened
echo -e "\nBuilding flattened/C3Caller.sol..."
forge build ../flattened/C3Caller.sol
echo -e "\nBuilding flattened/dapp..."
forge build ../flattened/dapp/
echo -e "\nBuilding flattened/gov..."
forge build ../flattened/gov/
echo -e "\nBuilding flattened/upgradeable..."
forge build ../flattened/upgradeable
echo -e "\nBuilding flattened/utils..."
forge build flattened/utils
echo -e "\nBuilding flattened/uuid..."
forge build flattened/uuid
