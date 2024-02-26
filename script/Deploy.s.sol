// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.12;

import "forge-std/Script.sol";
import "../contracts/v2/FiatTokenV2_2.sol";

contract DeployFiatToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        FiatTokeV2_2 fiatToken = new FiatTokenV2_2();
        vm.stopBroadcast();
    }
}
