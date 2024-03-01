// SPDX-License-Identifier: GPL-3.0
pragma experimental ABIEncoderV2;
pragma solidity >=0.6.12 <0.9.0;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IOmnibridge, IERC677} from "./interface/IOmnibridge.sol";
import {IAMB} from "./interface/IAMB.sol";
import {IBridgeValidators} from "./interface/IBridgeValidators.sol";
import {FiatTokenV2_2} from "../contracts/v2/FiatTokenV2_2.sol";
import {FiatTokenProxy} from "../contracts/v1/FiatTokenProxy.sol";
import {MockERC20} from "./contracts/MockERC20.sol";

contract ethereumTest is Test {

    IOmnibridge omnibridge;
    IAMB amb;
    IBridgeValidators bridgeValidators;
    FiatTokenV2_2 eurc;
    address sender;
    address testValidator;

    event UserRequestForAffirmation(bytes32 indexed messageId, bytes encodedData);
    event RelayedMessage(address indexed sender, address indexed executor, bytes32 indexed messageId, bool status);
    event ValidatorAdded(address indexed validator);
    event RequiredSignaturesChanged(uint256 requiredSignatures);

    function setUp() public {
        omnibridge = IOmnibridge(vm.envAddress("FOREIGN_OMNIBRIDGE"));
        amb = IAMB(vm.envAddress("FOREIGN_AMB"));
        bridgeValidators = IBridgeValidators(vm.envAddress("FOREIGN_VALIDATOR_CONTRACT"));
        eurc = FiatTokenV2_2(vm.envAddress("EURC"));
        sender = makeAddr("sender");
        testValidator = vm.envAddress("VALIDATOR_ADDRESS");

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

    // ==================================== End 2 End testing =================================

    function test_relayTokens() public {
        uint256 senderBalanceBefore = eurc.balanceOf(sender);
        uint256 omniBridgeBalanceBefore = eurc.balanceOf(address(omnibridge));

        uint256 amountToTransfer = 500e6;

        address omnibridgeOwner= omnibridge.owner();
        uint256 defaultMaxPerTx = omnibridge.maxPerTx(address(0));
        uint256 defaultExecutionMaxPerTx = omnibridge.executionMaxPerTx(address(0));

        // set new default maxPerTx and executionMaxPerTx to pass the _setLimits & _setExecutionLimits checks
        vm.startPrank(omnibridgeOwner);
        omnibridge.setMaxPerTx(address(0),defaultMaxPerTx/1e15);
        omnibridge.setExecutionMaxPerTx(address(0),defaultExecutionMaxPerTx/1e15);
        vm.stopPrank();

        // relay EURC
        vm.startPrank(sender);
        eurc.approve(address(omnibridge),amountToTransfer);
        omnibridge.relayTokens(IERC677(address(eurc)),amountToTransfer);
        vm.stopPrank();

        assertEq(eurc.balanceOf(sender), senderBalanceBefore - amountToTransfer);
        assertEq(eurc.balanceOf(address(omnibridge)),omniBridgeBalanceBefore + amountToTransfer);
    }



    function test_receiveFromGC() public{
        setNewValidator();
        relayFromETH(); // need to relay from ETH first in order to initialize the bridge limit

        // To be replaced: Value obtained after running gnosisTest.t.sol::test_subsequentRelayTokenFromGnosis()
        bytes memory signatureFromGC = hex'011b43417905e34b4c0f581dd4162ed6b84805e830ad8a3ae9707d3e499fd95338f035087628f01c6a0583690e0b68cb014928cd64ab1069a6a64d225b9ab8ca21f2';
        bytes memory messageFromGC = hex'00050000a7823d6f1e31569f51861e345b30c6bebf70ebe700000000000145a4f6a78083ca3e2a662d6dd1703c939c8ace2e268d88ad09518695c6c3712ac10a214be5109a655671000927c00101806401272255bb0000000000000000000000001abaea1f7c830bd89acc67ec4af516284b1bc33c000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681000000000000000000000000000000000000000000000000000000001dcd6500';
        bytes32 messageId = 0x00050000a7823d6f1e31569f51861e345b30c6bebf70ebe700000000000145a4;


        vm.prank(sender);
        vm.expectEmit(address(amb));
        emit RelayedMessage(address(vm.envAddress("HOME_OMNIBRIDGE")),address(omnibridge),messageId, true);
        amb.executeSignatures(messageFromGC,signatureFromGC);

    }

    // ======================== Unit Test ======================================
       function test_CreateNewValidator() public {

        address bridgeValidatorOwner = bridgeValidators.owner();

        vm.startPrank(bridgeValidatorOwner);
        vm.expectEmit(address(bridgeValidators));
        emit RequiredSignaturesChanged(1);
        bridgeValidators.setRequiredSignatures(1);
        vm.expectEmit(address(bridgeValidators));
        emit ValidatorAdded(testValidator);
        bridgeValidators.addValidator(testValidator);
        vm.stopPrank();
    }

    function test_VariedDecimal() public {
        string memory tokenName = "A token";
        string memory tokenSymbol = "ABC";

        // decimals less than 18 will cause revert error
        // revert here: https://github.com/gnosischain/omnibridge/blob/master/contracts/upgradeable_contracts/components/common/TokensBridgeLimits.sol#L247
        for(uint8 i=1; i<18; i++){
            MockERC20 token = new MockERC20(tokenName, tokenSymbol, 1e36, i, sender); // tokenName,tokenSymbol,initialSupply,decimal,receiver
            vm.startPrank(sender);
            token.approve(address(omnibridge),1e36);
            vm.expectRevert();
            omnibridge.relayTokens(IERC677(address(token)),1e18);
            vm.stopPrank();
        }
        // decimals more than 18 will not revert
        for(uint8 i=18; i<24; i++){
            MockERC20 token = new MockERC20(tokenName, tokenSymbol, 1e36, i, sender);
            vm.startPrank(sender);
            token.approve(address(omnibridge),1e36);
            omnibridge.relayTokens(IERC677(address(token)),1e18);
            vm.stopPrank();
        }

        uint256 defaultDailyLimit = omnibridge.dailyLimit(address(0));
        uint256 defaultExecutionDailyLimit = omnibridge.executionDailyLimit(address(0));

        // reset default dailyLimit and executionDailyLimit
        vm.startPrank(omnibridge.owner());
        omnibridge.setDailyLimit(address(0),defaultDailyLimit*10);
        omnibridge.setExecutionDailyLimit(address(0),defaultExecutionDailyLimit*10);
        vm.stopPrank();

        // will not revert after default dailyLimit and executionDailyLimit modified
        for(uint8 i=1; i<24; i++){
            MockERC20 token = new MockERC20(tokenName, tokenSymbol, 1e36, i, sender);
            vm.startPrank(sender);
            token.approve(address(omnibridge),1e36);
            omnibridge.relayTokens(IERC677(address(token)),1e18);
            vm.stopPrank();
        }

        // reset default dailyLimit and executionDailyLimit
        vm.startPrank(omnibridge.owner());
        omnibridge.setDailyLimit(address(0),defaultDailyLimit+1e18);
        omnibridge.setExecutionDailyLimit(address(0),defaultExecutionDailyLimit+1e18);
        vm.stopPrank();

        // will not revert after default dailyLimit and executionDailyLimit modified
        for(uint8 i=1; i<24; i++){
            MockERC20 token = new MockERC20(tokenName, tokenSymbol, 1e36, i, sender);
            vm.startPrank(sender);
            token.approve(address(omnibridge),1e36);
            omnibridge.relayTokens(IERC677(address(token)),1e18);
            vm.stopPrank();
        }
    }

    // ======================= Helper function =================================
    function setNewValidator() public {
        address bridgeValidatorOwner = bridgeValidators.owner();
        vm.startPrank(bridgeValidatorOwner);
        bridgeValidators.setRequiredSignatures(1);
        bridgeValidators.addValidator(testValidator);
        vm.stopPrank();
    }


    function setDefaultBridgeLimit() public {

        uint256 defaultDailyLimit = omnibridge.dailyLimit(address(0));
        uint256 defaultExecutionDailyLimit = omnibridge.executionDailyLimit(address(0));

        // reset default dailyLimit and executionDailyLimit
        vm.startPrank(omnibridge.owner());
        omnibridge.setDailyLimit(address(0),defaultDailyLimit*10);
        omnibridge.setExecutionDailyLimit(address(0),defaultExecutionDailyLimit*10);
        vm.stopPrank();
    }


    function relayFromETH() public {
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
    }
}