// SPDX-License-Identifier: GPL-3.0
pragma experimental ABIEncoderV2;
pragma solidity >=0.6.12 <0.9.0;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdUtils.sol";
import {IOmnibridge, IERC677} from "../interface/IOmnibridge.sol";
import {IAMB} from "../interface/IAMB.sol";
import {IBridgeValidators} from "../interface/IBridgeValidators.sol";
import {FiatTokenV2_2} from "../../contracts/v2/FiatTokenV2_2.sol";
import {FiatTokenProxy} from "../../contracts/v1/FiatTokenProxy.sol";
import {USDCTransmuter} from "../../contracts/USDCTransmuter.sol";
import {IPermittableToken} from "../../contracts/interface/IPermittableToken.sol";
import {MasterMinter} from "../../contracts/minting/MasterMinter.sol";
import {IAMBBridgeHelper} from "../interface/IAMBBridgeHelper.sol";


contract gnosisTest is Test {
    IOmnibridge omnibridge;
    IAMBBridgeHelper ambBridgeHelper;
    FiatTokenV2_2 usdcE;
    MasterMinter masterMinter;
    IBridgeValidators bridgeValidators;
    IAMB amb;
    USDCTransmuter usdcTransmuter;
    address usdcOnGC;
    address testValidator;
    uint256 usdcEMinterAllowance;
    address foreignOmnibridge;
    address sender;

    event UserRequestForSignature(bytes32 messageId, bytes encodedData);
    event TokensBridged(address indexed token, address indexed recipient, uint256 value, bytes32 indexed messageId);
    event AffirmationCompleted(address indexed sender,address indexed executor,bytes32 indexed messageId,bool status);

    function setUp() public {
        omnibridge = IOmnibridge(vm.envAddress("HOME_OMNIBRIDGE"));
        foreignOmnibridge = vm.envAddress("FOREIGN_OMNIBRIDGE");
        usdcE =FiatTokenV2_2(vm.envAddress("USDCE"));
        usdcTransmuter = USDCTransmuter(vm.envAddress("USDC_TRANSMUTER")); // for testing only
        usdcOnGC = vm.envAddress("USDC_ON_GNO");
        masterMinter = MasterMinter(0x55715Acb53a53332Fc2EBEC4a4ce50ab6086C4E0);
        usdcEMinterAllowance = 1e20;
        bridgeValidators = IBridgeValidators(vm.envAddress("HOME_VALIDATOR_CONTRACT"));
        amb = IAMB(vm.envAddress("HOME_AMB"));
        ambBridgeHelper = IAMBBridgeHelper(vm.envAddress("AMB_BRIDGE_HELPER"));
        testValidator = vm.envAddress("VALIDATOR_ADDRESS"); // new validator for testing purpose
        sender = makeAddr("sender");

        vm.startPrank(masterMinter.owner());
        masterMinter.configureController(omnibridge.owner(), address(usdcTransmuter)); // controller, worker
        vm.stopPrank();

        vm.prank(omnibridge.owner());
        masterMinter.configureMinter(usdcEMinterAllowance);

        setNewValidator();

    }

    function test_ReceiveFromETH() public {

        // TODO: get messageData(encodedData) and messageId from event from ethereumTest.t.sol::test_relayTokensAndCall
        bytes memory messageData = hex'000500004ac82b41bd819dd871590b510316f2385cb196fb0000000000023bef88ad09518695c6c3712ac10a214be5109a655671f6a78083ca3e2a662d6dd1703c939c8ace2e268d001e84800101000164c5345761000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000093417aa0ccb3b63480605aec92174fc4d2a717eb000000000000000000000000000000000000000000000000000000000000271000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000d6153f5af5679a75cc85d8974463545181f48772';
        bytes32 messageId =0x000500004ac82b41bd819dd871590b510316f2385cb196fb0000000000023bef;
        uint256 bridgedAmount = 10_000; // according to value `amountToRelay` from ethereumTest.t.sol::test_relayTokensAndCall

        vm.startPrank(testValidator);

        vm.expectEmit(address(omnibridge));
        emit TokensBridged(usdcOnGC, address(usdcTransmuter),bridgedAmount , messageId);
        vm.expectEmit(address(amb));
        emit AffirmationCompleted(foreignOmnibridge, address(omnibridge), messageId, true);
        amb.executeAffirmation(messageData);

        vm.stopPrank();

    }


    function test_transferUSDCEfromGnosis() public {

        uint256 amount = 1e8;

        IERC677 usdc = IERC677(address(usdcOnGC));
        uint256 transmuterUSDCBalanceBefore = usdc.balanceOf(address(usdcTransmuter));


        vm.prank(address(omnibridge));
        usdc.mint(sender,amount);

        assertEq(usdc.balanceOf(sender),amount);

        vm.startPrank(sender);

        usdc.approve(address(usdcTransmuter),amount);
        usdcTransmuter.deposit(amount);

        assertEq(usdcE.balanceOf(sender),amount);
        assertEq(usdc.balanceOf(address(usdcTransmuter)), transmuterUSDCBalanceBefore + amount);

        usdcE.approve(address(usdcTransmuter),amount);
        usdcTransmuter.bridgeUSDCE(sender,amount);

        assertEq(usdcE.balanceOf(sender),0);
        assertEq(usdc.balanceOf(address(usdcTransmuter)),0);

        vm.stopPrank();
    }

    function testFuzz_transferUSDCEfromGnosis(uint256 amount) public {

        IERC677 usdc = IERC677(address(usdcOnGC));
        uint256 availableUSDCToBridge = omnibridge.dailyLimit(usdcOnGC) - omnibridge.totalSpentPerDay(usdcOnGC,omnibridge.getCurrentDay());
        uint256 maxUSDCToBridge = omnibridge.maxPerTx(usdcOnGC) < availableUSDCToBridge ?  omnibridge.maxPerTx(usdcOnGC) : availableUSDCToBridge;
        amount = bound(amount,  omnibridge.minPerTx(usdcOnGC),  maxUSDCToBridge);
        uint256 transmuterUSDCBalanceBefore = usdc.balanceOf(address(usdcTransmuter));


        vm.prank(address(omnibridge));
        usdc.mint(sender,amount);

        assertEq(IERC677(address(usdcOnGC)).balanceOf(sender),amount);

        vm.startPrank(sender);
        usdc.approve(address(usdcTransmuter),amount);
        usdcTransmuter.deposit(amount);

        assertEq(usdcE.balanceOf(sender),amount);
        assertEq(usdc.balanceOf(address(usdcTransmuter)), transmuterUSDCBalanceBefore + amount);

        usdcE.approve(address(usdcTransmuter),amount);
        usdcTransmuter.bridgeUSDCE(sender,amount);

        assertEq(usdcE.balanceOf(sender),0);
        assertEq(usdc.balanceOf(address(usdcTransmuter)),0);
        vm.stopPrank();




    }

    function test_submitSignature() public{
        bytes memory signature = hex'7419e23af51e5266c52f8c992999f4ffe2cd2abe2d8bcf89d9cad16f9cf23b310aec1e0f1fb409c26ae3d6223a69bbf6d246ee4db839d08aaab232a8d598fc581c';
        bytes memory messageData = hex'00050000a7823d6f1e31569f51861e345b30c6bebf70ebe70000000000014938f6a78083ca3e2a662d6dd1703c939c8ace2e268d88ad09518695c6c3712ac10a214be5109a655671000927c00101806401272255bb000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681000000000000000000000000000000000000000000000000000000000000090c';
        vm.prank(testValidator);
        amb.submitSignature(signature, messageData);

        // Collect the signature to call ForeignAMB.executeSignature();
        bytes memory signatures = ambBridgeHelper.getSignatures(messageData);

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