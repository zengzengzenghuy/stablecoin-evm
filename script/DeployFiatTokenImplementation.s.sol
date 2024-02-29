// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.12;

import "forge-std/Script.sol";
import {FiatTokenV2_2 } from "../contracts/v2/FiatTokenV2_2.sol";

contract DeployFiatToken is Script {
    event NewContract(address newContract);
    address THROWAWAY_ADDRESS = 0x0000000000000000000000000000000000000001;


    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // deploy with contract artifact
        FiatTokenV2_2 fiatToken = new FiatTokenV2_2();
        emit NewContract(address(fiatToken));
        fiatToken.initialize("","","",0,THROWAWAY_ADDRESS,THROWAWAY_ADDRESS,THROWAWAY_ADDRESS,THROWAWAY_ADDRESS);
        fiatToken.initializeV2("");
        fiatToken.initializeV2_1(THROWAWAY_ADDRESS);
        address[] memory emptyArray;
        fiatToken.initializeV2_2(emptyArray,"");

        vm.stopBroadcast();
    }
}
