// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.12;

import "forge-std/Script.sol";
import {FiatTokenV2_2 } from "../contracts/v2/FiatTokenV2_2.sol";
import {FiatTokenProxy} from "../contracts/v1/FiatTokenProxy.sol";
import {MasterMinter} from "../contracts/minting/MasterMinter.sol";


contract DeployProxyAndMinter is Script {
    event NewContract(address newContract);
    FiatTokenV2_2 fiatTokenV2_2Proxy;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAdmin = vm.envAddress("PROXY_ADMIN");
        address ownerAddress = vm.envAddress("OWNER");
        address pauserAddress = vm.envAddress("PAUSER");
        address blackListerAddress = vm.envAddress("BLACKLISTER");
        address lostAndFoundAddress = vm.envAddress("LOST_AND_FOUND");
        address implementation = vm.envAddress("IMPLEMENTATION");

        vm.startBroadcast(deployerPrivateKey);

       //  address implementation = 0x8ca58c03D7F6326e8CFAC47fE263b3b1ed417ec6; // address from DeployFiatTokenImplementation.s.sol
        address[] memory emptyArray;

        FiatTokenProxy fiatTokenProxy = new FiatTokenProxy(implementation);
        emit NewContract(address(fiatTokenProxy));

        MasterMinter mastermint = new MasterMinter(address(fiatTokenProxy));
        emit NewContract(address(mastermint));
        mastermint.transferOwnership(ownerAddress);

        fiatTokenProxy.changeAdmin(proxyAdmin);

        fiatTokenV2_2Proxy = FiatTokenV2_2(address(fiatTokenProxy));

        fiatTokenV2_2Proxy.initialize("Bridged EURC (Gnosis)","EURC.e","EUR",6,address(mastermint),pauserAddress,blackListerAddress,ownerAddress);
        fiatTokenV2_2Proxy.initializeV2("Bridged EURC (Gnosis)");
        fiatTokenV2_2Proxy.initializeV2_1(lostAndFoundAddress);
        fiatTokenV2_2Proxy.initializeV2_2(emptyArray,"EURC.e");

        vm.stopBroadcast();
    }
}
