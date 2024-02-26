// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.12;

import "forge-std/Script.sol";
import {FiatTokenV2_2 } from "../contracts/v2/FiatTokenV2_2.sol";



contract DeployFiatToken is Script {
    event NewContract(address newContract);
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        FiatTokenV2_2 fiatToken = new FiatTokenV2_2();

        emit NewContract(address(fiatToken));
        vm.stopBroadcast();
    }
}
