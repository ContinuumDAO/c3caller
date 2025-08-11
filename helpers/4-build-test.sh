#!/bin/bash

echo -e "\nBuilding test/C3Caller.t.sol..."
forge build ./test/C3Caller.t.sol
echo -e "\nBuilding test/dapp..."
forge build ./test/dapp/
echo -e "\nBuilding test/gov..."
forge build ./test/gov/
echo -e "\nBuilding test/helpers..."
forge build ./test/helpers/
echo -e "\nBuilding test/upgradeable..."
forge build ./test/upgradeable/
echo -e "\nBuilding test/uuid..."
forge build ./test/uuid/
