// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.12;

import "forge-std/Script.sol";

import {MasterMinter} from "../contracts/minting/MasterMinter.sol";


contract SetWorker is Script {
    event NewContract(address newContract);
    address THROWAWAY_ADDRESS = 0x0000000000000000000000000000000000000001;
    MasterMinter masterMinter;

    function run() external {

        address worker = vm.envAddress("WORKER");
        address ownerPrivateKey = vm.envAddress("OWNER_PRIVATE_KEY");
        address controller = vm.envAddress("CONTROLLER");
        address controllerPrivateKey = vm.envAddress("CONTROLLER_PRIVATE_KEY");
        address masterMinterAddress = vm.envAddress("MASTER_MINTER");
        uint256 allowance = vm.envUint("ALLOWANCE");

        masterMinter = MasterMinter(masterMinterAddress);

        vm.startBroadcast(ownerPrivateKey);
        masterMinter.configureController(controller, worker);
        vm.stopBroadcast();

        vm.startBroadcast(controllerPrivateKey);
        masterMinter.configureMinter(allowance);
        vm.stopBroadcast();





    }
}