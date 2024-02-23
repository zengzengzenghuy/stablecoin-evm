const viem = require("viem");
const { createPublicClient, http, createWalletClient } = require("viem");
const { gnosis } = require("viem/chains");
const { privateKeyToAccount } = require("viem/accounts");
const fiatTokenABI = require("../out/FiatTokenV2_2.sol/FiatTokenV2_2.json");
const masterMinterABI = require("../out/MasterMinter.sol/MasterMinter.json");
const fiatTokenProxyABI = require("../out/FiatTokenProxy.sol/FiatTokenProxy.json");
const fs = require("fs");
require("dotenv").config();

const client = createWalletClient({
  chain: gnosis,
  transport: http(),
});

const publicClient = createPublicClient({
  chain: gnosis,
  transport: http(),
});

const account = privateKeyToAccount(process.env.PRIVATE_KEY);

console.log("token name: ", process.env.TOKEN_NAME);
console.log("lostAndFound address: ", process.env.OWNER);
console.log("token symbol: ", process.env.TOKEN_SYMBOL);
console.log("token currency: ", process.env.TOKEN_CURRENCY);
console.log("pauser: ", process.env.OWNER);
console.log("blacklister: ", process.env.OWNER);
console.log("owner: ", process.env.OWNER);

const THROWAWAY_ADDRESS = "0x0000000000000000000000000000000000000001";
const tokenName = process.env.TOKEN_NAME;
const lostAndFoundAddress = process.env.OWNER;
const tokenSymbol = process.env.TOKEN_SYMBOL;
const tokenCurrency = process.env.TOKEN_CURRENCY;
const tokenDecimals = 6;
const pauserAddress = process.env.OWNER;
const blacklisterAddress = process.env.OWNER;
const ownerAddress = process.env.OWNER;

// Need to update after deployment
const outputData = JSON.parse(fs.readFileSync("output.json"));

const IMPLEMENTATION_ADDRESS = outputData.FiatTokenImplementation;
const PROXY_ADDRESS = outputData.FiatTokenProxy;
const MASTER_MINTER_ADDRESS = outputData.MasterMinter;

async function main() {
  if (process.argv.slice(2) == "implementation") {
    console.log("initializing implementation contract with dummy value...");
    const implementation_init = await client.writeContract({
      account,
      abi: fiatTokenABI.abi,
      functionName: "initialize",
      address: IMPLEMENTATION_ADDRESS,
      args: [
        "",
        "",
        "",
        0,
        THROWAWAY_ADDRESS,
        THROWAWAY_ADDRESS,
        THROWAWAY_ADDRESS,
        THROWAWAY_ADDRESS,
      ],
    });

    console.log(`initialize Tx successful: ${implementation_init}`);

    const implementation_initV2 = await client.writeContract({
      account,
      abi: fiatTokenABI.abi,
      functionName: "initializeV2",
      address: IMPLEMENTATION_ADDRESS,
      args: [""],
    });

    console.log(
      `initializeV2 Tx successful with hash: ${implementation_initV2}`
    );

    const implementatoin_init_v2_1 = await client.writeContract({
      account,
      abi: fiatTokenABI.abi,
      functionName: "initializeV2_1",
      address: IMPLEMENTATION_ADDRESS,
      args: [THROWAWAY_ADDRESS],
    });

    console.log(
      `initializeV2_1 Tx successful with hash: ${implementatoin_init_v2_1}`
    );

    const implementation_init_v2_2 = await client.writeContract({
      account,
      abi: fiatTokenABI.abi,
      functionName: "initializeV2_2",
      address: IMPLEMENTATION_ADDRESS,
      args: [[], ""],
    });

    console.log(
      `initializeV2_2 Tx successful with hash: ${implementation_init_v2_2}`
    );
  } else if (process.argv.slice(2) == "proxy") {
    const changeAdmin = await client.writeContract({
      account,
      abi: fiatTokenProxyABI.abi,
      functionName: "changeAdmin",
      address: PROXY_ADDRESS,
      args: [ownerAddress],
    });

    console.log(`changeAdmin Tx successful with hash: ${changeAdmin}`);

    // initialize proxy

    const proxy_init = await client.writeContract({
      account,
      abi: fiatTokenABI.abi,
      functionName: "initialize",
      address: PROXY_ADDRESS,
      args: [
        tokenName,
        tokenSymbol,
        tokenCurrency,
        tokenDecimals,
        MASTER_MINTER_ADDRESS,
        pauserAddress,
        blacklisterAddress,
        ownerAddress,
      ],
    });

    console.log(`initialize Tx successful with hash: ${proxy_init}`);

    const proxy_initV2 = await client.writeContract({
      account,
      abi: fiatTokenABI.abi,
      functionName: "initializeV2",
      address: PROXY_ADDRESS,
      args: [tokenName],
    });

    console.log(`initializeV2 Tx successful with hash: ${proxy_initV2}`);

    const proxy_init_v2_1 = await client.writeContract({
      account,
      abi: fiatTokenABI.abi,
      functionName: "initializeV2_1",
      address: PROXY_ADDRESS,
      args: [lostAndFoundAddress],
    });

    console.log(`initializeV2 Tx successful with hash: ${proxy_init_v2_1}`);

    const proxy_init_v2_2 = await client.writeContract({
      account,
      abi: fiatTokenABI.abi,
      functionName: "initializeV2_2",
      address: PROXY_ADDRESS,
      args: [[], tokenSymbol],
    });

    console.log(`initializeV2 Tx successful with hash: ${proxy_init_v2_2}`);
  } else if (process.argv.slice(2) == "masterMinter") {
    const transferOwnership = await client.writeContract({
      account,
      abi: masterMinterABI.abi,
      functionName: "transferOwnership",
      address: MASTER_MINTER_ADDRESS,
      args: [ownerAddress],
    });

    console.log(`initialize Tx successful with hash: ${transferOwnership}`);
  } else {
    console.log("Incorrect");
  }
}

main();
