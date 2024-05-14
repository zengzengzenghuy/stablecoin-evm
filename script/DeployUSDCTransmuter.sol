// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.12;

import "forge-std/Script.sol";

import { USDCTransmuter } from "../contracts/USDCTransmuter.sol";

contract DeployUSDCTransmuter is Script {
    event NewContract(address newContract);

    function run() external {
        address usdce = vm.envAddress("USDCE");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        USDCTransmuter usdcTransmuter = new USDCTransmuter(usdce);
        emit NewContract(address(usdcTransmuter));
        vm.stopBroadcast();
    }
}
