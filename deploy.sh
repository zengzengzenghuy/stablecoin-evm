#!/bin/bash

source .env

# Step 2: RUN forge create for SignatureChecker
JSON_OUTPUT=$(forge create --rpc-url https://rpc.gnosischain.com --private-key $PRIVATE_KEY --verify --verifier etherscan --etherscan-api-key $GNOSISSCAN_API_KEY --chain-id 100 --json ./contracts/util/SignatureChecker.sol:SignatureChecker)

LIB_ADDRESS=$(jq -r '.deployedTo' <<< "$JSON_OUTPUT")
echo "LIB_ADDRESS $LIB_ADDRESS"

# Update the libraries field in foundry.toml
foundryTomlPath="foundry.toml"

# Check if libraries field exists, if not, add it
if grep -q "libraries =" "$foundryTomlPath"; then
  sed -i "s|libraries =.*|libraries = [\"./contracts/utils/SignatureChecker.sol:SignatureChecker:$LIB_ADDRESS\"]|" "$foundryTomlPath"
else
  echo "libraries = [\"./contracts/utils/SignatureChecker.sol:SignatureChecker:$LIB_ADDRESS\"]" >> "$foundryTomlPath"
fi


# Step 4: RUN forge create for FiatTokenV2_2
JSON_OUTPUT=$(forge create --rpc-url https://rpc.gnosischain.com --private-key $PRIVATE_KEY --verify --verifier etherscan --etherscan-api-key $GNOSISSCAN_API_KEY  --json ./contracts/v2/FiatTokenV2_2.sol:FiatTokenV2_2 --chain-id 100)

IMPLEMENTATION_ADDRESS=$(jq -r '.deployedTo' <<< "$JSON_OUTPUT")
echo "IMPLEMENTATION $IMPLEMENTATION_ADDRESS"

# Step 5: RUN forge create for FiatTokenProxy
JSON_OUTPUT=$(forge create --rpc-url https://rpc.gnosischain.com --private-key $PRIVATE_KEY --verify --verifier etherscan --etherscan-api-key $GNOSISSCAN_API_KEY  --json ./contracts/v1/FiatTokenProxy.sol:FiatTokenProxy --constructor-args $LIB_ADDRESS --chain-id 100)

PROXY_ADDRESS=$(jq -r '.deployedTo' <<< "$JSON_OUTPUT")
echo "PROXY $PROXY_ADDRESS"

# Step 6: RUN forge create for MasterMinter
JSON_OUTPUT=$(forge create --rpc-url https://rpc.gnosischain.com --private-key $PRIVATE_KEY ./contracts/minting/MasterMinter.sol:MasterMinter --verify --verifier etherscan --etherscan-api-key $GNOSISSCAN_API_KEY --chain-id 100  --json --constructor-args $LIB_ADDRESS)

MASTER_MINTER_ADDRESS=$(jq -r '.deployedTo' <<< "$JSON_OUTPUT")
echo "MASTER MINTER $MASTER_MINTER_ADDRESS"

# Step 7: Create JSON file
JSON_CONTENT="{\"FiatTokenImplementation\":\"$IMPLEMENTATION_ADDRESS\", \"FiatTokenProxy\":\"$PROXY_ADDRESS\",\"MasterMinter\":\"$MASTER_MINTER_ADDRESS\"}"
echo $JSON_CONTENT > output.json

# Step 8: Run init.js
node ./scripts/init.js implementation
node ./scripts/init.js proxy
node ./scripts/init.js masterMinter
