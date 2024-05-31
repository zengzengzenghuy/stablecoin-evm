#!/usr/bin/env bash

source ../../.env

echo "End to End Test"

echo "Relay USDC from Ethereum"
forge test --match-test test_relayTokensAndCallFromETH --rpc-url $ETH_RPC_URL --json | jq > test_output/ETH_relayTokensAndCall.json
node utils/collectAffirmation.js
forge test --match-test test_receiveUSDCFromETH --rpc-url $GNOSIS_RPC_URL -v
echo "ETH->GC: Done ✅"


echo "Relay USDC from Gnosis Chain"
forge test --match-test test_relayUSDCEFromGC --rpc-url $GNOSIS_RPC_URL --json | jq > test_output/GNO_relayTokens.json
node utils/signAndGetSignature.js
forge test --match-test test_claimUSDC --rpc-url $ETH_RPC_URL -v
echo "GC->ETH: Done ✅"


echo "Unit & Fuzz Test"
forge test  --match-contract USDCTransmuterTest --rpc-url $GNOSIS_RPC_URL  -v
echo "Unit & Fuzz Test: :  Done ✅"