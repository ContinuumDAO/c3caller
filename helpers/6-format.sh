#!/bin/bash

echo -e "\nFormatting codebase..."

forge fmt src/
forge fmt test/
forge fmt script/
