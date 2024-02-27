# Deploy Guideline

1. Set up `.env` (refer to `.env.example`)
2. Setup the dev environment

```
    nvm use
    npm i -g yarn@1.22.19 # Install yarn if you don't already have it
    yarn install
    forge install
```

3. Deploy `FiatTokenV2_2.sol`: `source .env && forge script script/DeployFiatTokenImplementation.s.sol:DeployFiatToken --rpc-url $GNOSIS_RPC_URL --broadcast  --verify --chain-id 100 --etherscan-api-key=$GNOSISSCAN_API_KEY -vvvv`

4. Due to the openzeppelin contracts version issue, you need to change the `"@openzeppelin/contracts": "^3.1.0"`(default to 3.4.2) to `"@openzeppelin/contracts": "3.1.0"`, in order to compile correctly.

5. Delete `node_modules`  and `out`, then run `yarn install` again.
6. Update `IMPLEMENTATION` variable in `.env` with the address from step 3.
7. Deploy `FiatTokenProxy.sol` and `MasterMinter.sol`: `source .env && forge script script/DeployProxyAndMinter.s.sol:DeployProxyAndMinter --rpc-url $GNOSIS_RPC_URL --broadcast  --verify --chain-id 100 --etherscan-api-key=$GNOSISSCAN_API_KEY -vvvv`
8. Configure worker: `forge script script/SetWorker.s.sol:SetWorker --rpc-url $GNOSIS_RPC_URL --broadcast --chain-id 100`

# Register in Omnibridge

1. EURC on Ethereum: `0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c`

2. Omnibridge owner([0x7a48Dac683DA91e4faa5aB13D91AB5fd170875bd](https://gnosisscan.io/address/0x7a48dac683da91e4faa5ab13d91ab5fd170875bd)) calls Omnibridge setCustomTokenAddressPair(nativeTokenAddress, bridgedTokenAddress) with calldata: `0b71a4a70000000000000000000000001abaea1f7c830bd89acc67ec4af516284b1bc33c000000000000000000000000<EURC address on Gnosis Chain>` (replace <EURC address on Gnosis Chain> to the deployed token proxy contract)

## Deployment

### Gnosis Chain

1. EURC Token: [0x54E4cB2a4Fa0ee46E3d9A98D13Bea119666E09f6](https://gnosisscan.io/address/0x54e4cb2a4fa0ee46e3d9a98d13bea119666e09f6#code)
2. EURC Master Minter: [0xb9257660afe39ab09aff1fa29c189330da7a8398](https://gnosisscan.io/address/0xb9257660afe39ab09aff1fa29c189330da7a8398#code)
