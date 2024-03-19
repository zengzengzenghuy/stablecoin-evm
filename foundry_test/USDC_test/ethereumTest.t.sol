// SPDX-License-Identifier: GPL-3.0
pragma experimental ABIEncoderV2;
pragma solidity >=0.6.12 <0.9.0;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdUtils.sol";
import {IOmnibridge, IERC677} from "../interface/IOmnibridge.sol";
import {IAMB} from "../interface/IAMB.sol";
import {IBridgeValidators} from "../interface/IBridgeValidators.sol";
import {IERC20} from "../interface/IERC20.sol";
import {USDCTransmuter} from "../../contracts/USDCTransmuter.sol";

contract ethereumTest is Test {
    IOmnibridge omnibridge;
    IAMB amb;
    IERC20 usdc;
    IBridgeValidators bridgeValidators;
    address sender;
    address testValidator;
    address usdcTransmuter;

    event RelayedMessage(address indexed sender, address indexed executor, bytes32 indexed messageId, bool status);

    function setUp() public {
        omnibridge = IOmnibridge(vm.envAddress("FOREIGN_OMNIBRIDGE"));
        amb = IAMB(vm.envAddress("FOREIGN_AMB"));
        bridgeValidators = IBridgeValidators(vm.envAddress("FOREIGN_VALIDATOR_CONTRACT"));
        sender = 0xD6153F5af5679a75cC85D8974463545181f48772; // USDC holder on Ethereum
        testValidator = vm.envAddress("VALIDATOR_ADDRESS");
        usdc = IERC20(vm.envAddress("USDC_ON_ETH"));
        usdcTransmuter = vm.envAddress("USDC_TRANSMUTER");

        setNewValidator();
    }


    function test_relayTokensAndCall() public {
        uint256 amountToRelay = 10_000;
        uint256 senderBalanceBefore = usdc.balanceOf(sender);
        uint256 omnibridgeBalanceBefore = usdc.balanceOf(address(omnibridge));

        vm.startPrank(sender);

        usdc.approve(address(omnibridge),amountToRelay);
        // function relayTokensAndCall(IERC677 token,address _receiver,uint256 _value,bytes memory _data
        omnibridge.relayTokensAndCall(IERC677(address(usdc)),usdcTransmuter,amountToRelay, abi.encode(sender));
        assertEq(usdc.balanceOf(sender),senderBalanceBefore - amountToRelay);
        assertEq(usdc.balanceOf(address(omnibridge)),omnibridgeBalanceBefore + amountToRelay);

        vm.stopPrank();
    }

    function testFuzz_relayTokensAndCall(uint256 amount) public {
        uint256 availableUSDCToBridge = omnibridge.dailyLimit(address(usdc)) - omnibridge.totalSpentPerDay(address(usdc), omnibridge.getCurrentDay());
        uint256 maxUSDCToBridge = omnibridge.maxPerTx(address(usdc)) < availableUSDCToBridge ? omnibridge.maxPerTx(address(usdc)) : availableUSDCToBridge;
        amount = bound(amount, omnibridge.minPerTx(address(usdc)),maxUSDCToBridge);

        uint256 senderBalanceBefore = usdc.balanceOf(sender);
        uint256 omnibridgeBalanceBefore = usdc.balanceOf(address(omnibridge));

        vm.startPrank(sender);

        usdc.approve(address(omnibridge),amount);
        // function relayTokensAndCall(IERC677 token,address _receiver,uint256 _value,bytes memory _data
        omnibridge.relayTokensAndCall(IERC677(address(usdc)),usdcTransmuter,amount, abi.encode(sender));
        assertEq(usdc.balanceOf(sender),senderBalanceBefore - amount);
        assertEq(usdc.balanceOf(address(omnibridge)),omnibridgeBalanceBefore + amount);

        vm.stopPrank();

    }

    function test_receiveFromGC() public {
        // TODO: get signature from ambHelper.getSignature()
        bytes memory signatureFromGC = hex'011c7419e23af51e5266c52f8c992999f4ffe2cd2abe2d8bcf89d9cad16f9cf23b310aec1e0f1fb409c26ae3d6223a69bbf6d246ee4db839d08aaab232a8d598fc58';
        // TODO: get messageData(encodedData) and messageId from event UserRequestFromSignature
        bytes memory messageFromGC = hex'00050000a7823d6f1e31569f51861e345b30c6bebf70ebe70000000000014938f6a78083ca3e2a662d6dd1703c939c8ace2e268d88ad09518695c6c3712ac10a214be5109a655671000927c00101806401272255bb000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681000000000000000000000000000000000000000000000000000000000000090c';
        bytes32 messageId =0x00050000a7823d6f1e31569f51861e345b30c6bebf70ebe70000000000014938;

        vm.prank(sender);
        vm.expectEmit(address(amb));
        emit RelayedMessage(address(vm.envAddress("HOME_OMNIBRIDGE")),address(omnibridge),messageId, true);
        amb.executeSignatures(messageFromGC,signatureFromGC);

    }

    // ======================= Helper function =================================
    function setNewValidator() public {
        address bridgeValidatorOwner = bridgeValidators.owner();
        vm.startPrank(bridgeValidatorOwner);
        bridgeValidators.setRequiredSignatures(1);
        bridgeValidators.addValidator(testValidator);
        vm.stopPrank();
    }

}