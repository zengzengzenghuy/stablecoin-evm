// SPDX-License-Identifier: GPL-3.0
pragma experimental ABIEncoderV2;
pragma solidity >=0.6.12 <0.9.0;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IOmnibridge, IERC677} from "./contracts/IOmnibridge.sol";
import {FiatTokenV2_2} from "../contracts/v2/FiatTokenV2_2.sol";
import {FiatTokenProxy} from "../contracts/v1/FiatTokenProxy.sol";

contract ethereumTest is Test {

    IOmnibridge omnibridge;
    FiatTokenV2_2 eurc;
    address sender;

    // AMB = 0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e
    // Omnibridge = 0x88ad09518695c6c3712AC10a214bE5109a655671
    // EURC = 0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c
    function setUp() public {
        omnibridge = IOmnibridge(0x88ad09518695c6c3712AC10a214bE5109a655671);
        eurc = FiatTokenV2_2(0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c);
        sender = makeAddr("sender");
        address eurcHolder = 0x00253582b2a3FE112feEC532221d9708c64cEFAb; // EURC holder on Ethereum, for testing purpose
        vm.prank(eurcHolder);
        eurc.transfer(sender, 1_000e6); // transfer 1000 EURC

        // using deal won't work because forge-std has issue reading packed storage slot,
        // which is used in FiatTokenV_2
        // More info: https://github.com/foundry-rs/forge-std/issues/318
        // https://github.com/foundry-rs/forge-std/commit/fac7bd8d4e27f42067c4713fd231c3240fd8437a
        // https://github.com/foundry-rs/forge-std/pull/148/files
        //deal(address(eurc),sender,1_000_000,true); // true to increase total supply
    }
    function test_relayTokens() public {
        uint256 senderBalanceBefore = eurc.balanceOf(sender);
        uint256 omniBridgeBalanceBefore = eurc.balanceOf(address(omnibridge));

        uint256 amountToTransfer = 500e6;

        address omnibridgeOwner= omnibridge.owner();
        uint256 defaultMaxPerTx = omnibridge.maxPerTx(address(0));
        uint256 defaultExecutionMaxPerTx = omnibridge.executionMaxPerTx(address(0));

        // set new default maxPerTx and executionMaxPerTx to pass the checks
        vm.startPrank(omnibridgeOwner);
        omnibridge.setMaxPerTx(address(0),defaultMaxPerTx/100);
        omnibridge.setExecutionMaxPerTx(address(0),defaultExecutionMaxPerTx/100);
        vm.stopPrank();


        vm.startPrank(sender);
        eurc.approve(address(omnibridge),amountToTransfer);
        omnibridge.relayTokens(IERC677(address(eurc)),amountToTransfer);
        vm.stopPrank();
        assertEq(eurc.balanceOf(sender), senderBalanceBefore - amountToTransfer);
        assertEq(eurc.balanceOf(address(omnibridge)),omniBridgeBalanceBefore + amountToTransfer);
    }
}