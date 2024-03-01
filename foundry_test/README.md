# Forge test

## Note

1. For fork testing purpose, a new validator is added and requiredSignature is set to 1. Please create a fake validator and update in `.env` for `VALIDATOR_PRIVATE_KEY` and `VALIDATOR_ADDRESS`

## Dev

1. Run `cp .env.testing .env` and update `VALIDATOR_PRIVATE_KEY` and `VALIDATOR_ADDRESS` in `.env`.
2. Install `npm install`.

### End to end test

**Ethereum -> Gnosis Chain**

1. Relay EURC from Ethereum:
    1. run `forge test --fork-url <ETH_RPC_URL> --match-path foundry_test/ethereumTest.t.sol  --match-test  test_relayTokens -vvvv`.  Replace `<ETH_RPC_URL>`.
    2. Collect `messageId` and `encodedData` from the traces of the test from event `UserRequestForAffirmation(messageId, encodedData)`.
2. Receive EURC.e on Gnosis Chain:
    1. replace `messageData` with `encodedData` and `messageId` with data from step 1 in gnosisTest.t.sol::test_receiveFromEthereum().
    2. run `forge test --fork-url https://rpc.gnosischain.com  --match-path foundry_test/gnosisTest.t.sol --match-test test_receiveFromEthereum -vvvv`

**Gnosis Chain -> Ethereum**

1. Relay EURC.e from Gnosis Chain:
    1. run `forge test --fork-url https://rpc.gnosischain.com  --match-path foundry_test/gnosisTest.t.sol --match-test test_subsequentRelayTokenFromGnosis  -vvvv` .
    2. Collect `messageId` and `encodedData` from the traces of the test from event `UserRequestForSignature(messageId, encodedData)`
2. Sign message on behalf of validator:
    1. Replace `messageDataFromGc` to `encodedData` in `web3Sign.js` and run `node web3Sign.js`.
    2. Collect `signature` from the output.
3. Submit signature on behalf of validator:
    1. Replace `messageData` with `encodedData` and `signature` with `signature` from step 2 in gnosisTest.t.sol::test_submitSignatures().
    2. Run `forge test --fork-url https://rpc.gnosischain.com  --match-path foundry_test/gnosisTest.t.sol --match-test test_submitSignatures  -vvvv`
    3. Get signatures from the output.
4. Receive EURC from Ethereum:
    1. Replace `signatureFromGC` to `signature` and `messageFromGC` with `messageData` from step 3, and `messageId` from step 1.
    2. Run `forge test --fork-url <ETH_RPC_URL> --match-path foundry_test/ethereumTest.t.sol  --match-test  test_receiveFromGC -vvvv`.  Replace `<ETH_RPC_URL>`.

### Unit Test

1. Ethereum: `forge test --fork-url <ETH_RPC_URL> --match-path foundry_test/ethereumTest.t.sol  --no-match-test  test_relayTokens,test_receiveFromGC  -vvvv`
2. Gnosis Chain: `forge test --fork-url https://rpc.gnosischain.com  --match-path foundry_test/gnosisTest.t.sol --no-match-test test_receiveFromEthereum,test_subsequentRelayTokenFromGnosis,test_submitSignatures  -vvvv`

3. Testing tokens with different decimals.
    `forge test --fork-url <ETH_RPC_URL>  --match-path foundry_test/ethereumTest.t.sol --match-test test_VariedDecimal  -vvvv` &     `forge test --fork-url https://rpc.gnosischain.com  --match-path foundry_test/gnosisTest.t.sol --match-test test_VariedDecimal  -vvvv`

## Key contracts

1. EURC = 0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c
2. EURC.e = 0x54E4cB2a4Fa0ee46E3d9A98D13Bea119666E09f6
3. masterMinter = 0xB9257660afe39AB09AfF1Fa29C189330DA7a8398
4. EURC.e & masterMinter owner = 0x6ad101d4e877aee36e6644e3f083d1e8862cbe2a
5. HomeOmnibridge = 0xf6A78083ca3e2a662D6dd1703c939c8aCE2e268d
6. AMBBridgeHelper = 0x7d94ece17e81355326e3359115D4B02411825EdD
7. OmnibridgeFeeManager = 0x5dbC897aEf6B18394D845A922BF107FA98E3AC55
8. Home validator contract = 0xA280feD8D7CaD9a76C8b50cA5c33c2534fFa5008
