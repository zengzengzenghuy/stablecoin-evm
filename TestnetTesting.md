# Contract interaction between Sepolia and Chiado

## Key contracts

### Sepolia

1. AMB: [0xf2546d6648bd2af6a008a7e7c1542bb240329e11](https://sepolia.etherscan.io/address/0xf2546d6648bd2af6a008a7e7c1542bb240329e11)
2. Omnibridge: [0x63e47c5e3303dddcaf3b404b1ccf9eb633652e9e](https://sepolia.etherscan.io/address/0x63e47c5e3303dddcaf3b404b1ccf9eb633652e9e)
3. EURC: [0xd2304017a3d7ee3dce990916f024d961b5163b85](https://sepolia.etherscan.io/address/0xd2304017a3d7ee3dce990916f024d961b5163b85)
4. MasterMinter: [0x13284bbe5cfb2d79c1550d90147dbab8f46d6de6](https://sepolia.etherscan.io/address/0x13284bbe5cfb2d79c1550d90147dbab8f46d6de6)

### Chiado

1. AMB: [0x8448E15d0e706C0298dECA99F0b4744030e59d7d](https://gnosis-chiado.blockscout.com/address/0x8448E15d0e706C0298dECA99F0b4744030e59d7d)
2. Omnibridge: [0x82f63B9730f419CbfEEF10d58a522203838d74c8](https://gnosis-chiado.blockscout.com/address/0x82f63B9730f419CbfEEF10d58a522203838d74c8)
3. AMBHelper: [0x8D0B0E7926D017E2d3B8F629ec49731a8a24ee83](https://gnosis-chiado.blockscout.com/address/0x8D0B0E7926D017E2d3B8F629ec49731a8a24ee83)
4. Bridged EURC (Gnosis): [0x744c41672e4ca46004bb3973c686c4b03f596646](https://blockscout.chiadochain.net/address/0x744c41672e4ca46004bb3973c686c4b03f596646)
5. MasterMinter: [0x8485d7e2ec47efa599b2774a18fb6edb26d438b3](https://blockscout.chiadochain.net/address/0x8485d7e2ec47efa599b2774a18fb6edb26d438b3)

## Step by Step

1. (Chiado) Set default fee for Omnibridge token to 0:
  a. HOME_TO_FOREIGN_FEE: <https://gnosis-chiado.blockscout.com/tx/0x87c1185300ac65b865f594314df9c7a1f085495959f31e826e3482878b5f1f9b>
  b. FOREIGN_TO_HOME_FEE: <https://gnosis-chiado.blockscout.com/tx/0xd8869bd373d02361e979e0694875b1d1f53b13b945762ecd90692a246a379a47>

2. (Chiado) `setCustomTokenAddressPair(native token: EURC address on Sepolia, bridged token: EURC.e address on Chiado)`: <https://gnosis-chiado.blockscout.com/tx/0xc48470a2b1421c765134e7077ea1e3987948c0da2f45ba2285a5f273e3bd6a69>   (Please make sure that Omnibridge is configured as worker in MasterMinter with enough allowance to mint EURC.e)
3. Start bridging (Must be from Foreign to Home for the first time):
    1. Sepolia -> Chiado
          1. call EURC.approve: <https://sepolia.etherscan.io/tx/0x5b1fd0778b683379cbf7637d91e0f9518b9f3e357b33cfbd9da05bc46bfda08f>
          2. call Omnibridge.relayTokens: <https://sepolia.etherscan.io/tx/0x3050b6046afe4fa483b4736f108707d8024d0af66fb616718c616a66c6a755f8>
          3. Received on Chiado: <https://gnosis-chiado.blockscout.com/tx/0x3226ecde7d903fa23e7bed9f62aa05ef5971330731228196f2868867b5eb1e57?tab=index> (Token is initiated)
    2. Chiado -> Sepolia
          1. call EURC.e.approve: <https://gnosis-chiado.blockscout.com/tx/0xae77436ba00276e6d69c91884cd575562fb1f17c1dd433060dd3a5cee7adc71e>
          2. call Omnibridge.relayTokens: <https://gnosis-chiado.blockscout.com/tx/0xbd82f242371bbb0b3cf89c08d769a7f71cb98fc75779e4b7304ca30a493c7737>
          3. claim token on Sepolia by calling AMB.safeExecuteSignaturesWithAutoGasLimit(): <https://sepolia.etherscan.io/tx/0x7e9842cf02c499199d82d29c8b61458ce8686e489cbb0aac3f8c1163a8ba4e31>
