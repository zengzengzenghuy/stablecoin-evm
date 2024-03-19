// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.12;

import "forge-std/Script.sol";

import {USDCTransmuter} from "../contracts/USDCTransmuter.sol";


contract DeployProxyAndMinter is Script {
    event NewContract(address newContract);
    function run() external {
        address usdce = vm.envAddress("USDCE");
        address omnibridge = vm.envAddress("HOME_OMNIBRIDGE");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        USDCTransmuter usdcTransmuter = new USDCTransmuter(usdce,omnibridge);
        emit NewContract(address(usdcTransmuter));
        vm.stopBroadcast();
    }

}