// SPDX-License-Identifier: GPL-3.0
pragma experimental ABIEncoderV2;
pragma solidity >=0.6.12 <0.9.0;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IOmnibridge, IERC677} from "../interface/IOmnibridge.sol";
import {IOmnibridgeFeeManager} from "../interface/IOmnibridgeFeeManager.sol";
import {IBridgeValidators} from "../interface/IBridgeValidators.sol";
import {IAMB} from "../interface/IAMB.sol";
import {IAMBBridgeHelper} from "../interface/IAMBBridgeHelper.sol";
import {FiatTokenV2_2} from "../../contracts/v2/FiatTokenV2_2.sol";
import {FiatTokenProxy} from "../../contracts/v1/FiatTokenProxy.sol";
import {MasterMinter} from "../../contracts/minting/MasterMinter.sol";
import {MockERC20} from "../contracts/MockERC20.sol";

contract gnosisTest is Test {

    IOmnibridge omnibridge;
    FiatTokenV2_2 eurcE;
    MasterMinter masterMinter;
    IBridgeValidators bridgeValidators;
    IAMB amb;
    IAMBBridgeHelper ambBridgeHelper;
    address sender;
    address minter;
    address testValidator;
    uint256 mintingAllowance = 1_000_000_000e6; // 6 decimals

    event TokensBridged(address indexed token, address indexed recipient, uint256 value, bytes32 indexed messageId);
    event AffirmationCompleted(address indexed sender,address indexed executor,bytes32 indexed messageId,bool status);
    event ValidatorAdded(address indexed validator);
    event RequiredSignaturesChanged(uint256 requiredSignatures);
    event NewTokenRegistered(address indexed nativeToken, address indexed bridgedToken);
    event ControllerConfigured(address indexed _controller,address indexed _worker);
    event MinterConfigured(address indexed _msgSender,address indexed _minter,uint256 _allowance);

    function setUp() public {
        omnibridge = IOmnibridge(vm.envAddress("HOME_OMNIBRIDGE"));
        eurcE = FiatTokenV2_2(vm.envAddress("EURCE"));
        masterMinter = MasterMinter(vm.envAddress("MASTER_MINTER"));
        bridgeValidators = IBridgeValidators(vm.envAddress("HOME_VALIDATOR_CONTRACT"));
        amb = IAMB(vm.envAddress("HOME_AMB"));
        ambBridgeHelper = IAMBBridgeHelper(vm.envAddress("AMB_BRIDGE_HELPER"));
        sender = makeAddr("sender"); // sender = receiver from ETH
        testValidator = vm.envAddress("VALIDATOR_ADDRESS"); // new validator for testing purpose


        vm.startPrank(masterMinter.owner());
        masterMinter.configureController(omnibridge.owner(), address(omnibridge)); // controller, worker
        vm.stopPrank();

        vm.prank(omnibridge.owner());
        masterMinter.configureMinter(mintingAllowance);

        vm.prank(address(omnibridge));
        eurcE.mint(sender,1_000_000e6);

        assertEq(eurcE.balanceOf(sender), 1_000_000e6);

    }

    // ==================================== End 2 End testing =================================

    function test_receiveFromEthereum() public {
        setDefaultFee();
        setNewValidator();
        setCustomTokenPairAndBridgeLimit();

        // To be replaced:
        // Replace this with the data you get after running ethereumTest.t.sol::test_relayTokens()
        // messageData from event UserRequestFromAffirmation.encodedData from ethereumTest.t.sol::test_relayTokens()
       // bytes memory messageData = hex'000500004ac82b41bd819dd871590b510316f2385cb196fb000000000002385388ad09518695c6c3712ac10a214be5109a655671f6a78083ca3e2a662d6dd1703c939c8ace2e268d001e848001010001642ae87cdd0000000000000000000000001abaea1f7c830bd89acc67ec4af516284b1bc33c00000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681000000000000000000000000000000000000000000000000000000001dcd650000000000000000000000000000000000000000000000000000000000000000094575726f20436f696e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044555524300000000000000000000000000000000000000000000000000000000'; // required from ethereumTest.t.sol
        bytes memory messageData = hex'000500004ac82b41bd819dd871590b510316f2385cb196fb000000000002387e88ad09518695c6c3712ac10a214be5109a655671f6a78083ca3e2a662d6dd1703c939c8ace2e268d001e848001010001642ae87cdd0000000000000000000000001abaea1f7c830bd89acc67ec4af516284b1bc33c00000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681000000000000000000000000000000000000000000000000000000001dcd650000000000000000000000000000000000000000000000000000000000000000094575726f20436f696e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044555524300000000000000000000000000000000000000000000000000000000';
        // messageId from event UserRequestFromAffirmation.messageId from ethereumTest.t.sol::test_relayTokens()
        bytes32 messageId = 0x000500004ac82b41bd819dd871590b510316f2385cb196fb000000000002387e;

        address ForeignOmnibridge = vm.envAddress("FOREIGN_OMNIBRIDGE");
        uint256 amountToReceive = 500e6;

        vm.startPrank(testValidator);

        vm.expectEmit(address(omnibridge));
        emit TokensBridged(address(eurcE), sender, amountToReceive, messageId);
        vm.expectEmit(address(amb));
        emit AffirmationCompleted(ForeignOmnibridge, address(omnibridge), messageId, true);

        amb.executeAffirmation(messageData);

        vm.stopPrank();

    }


    function test_subsequentRelayTokenFromGnosis() public {
        setUpForHome();
        vm.startPrank(sender);
        eurcE.approve(address(omnibridge),1_000e6);
        omnibridge.relayTokens(IERC677(address(eurcE)),500e6);
        vm.stopPrank();
    }

    function test_submitSignatures() public {
        setUpForHome();
        vm.startPrank(sender);
        eurcE.approve(address(omnibridge),1_000e6);
        omnibridge.relayTokens(IERC677(address(eurcE)),500e6);
        vm.stopPrank();

         bytes memory messageData = hex'00050000a7823d6f1e31569f51861e345b30c6bebf70ebe700000000000145a4f6a78083ca3e2a662d6dd1703c939c8ace2e268d88ad09518695c6c3712ac10a214be5109a655671000927c00101806401272255bb0000000000000000000000001abaea1f7c830bd89acc67ec4af516284b1bc33c000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681000000000000000000000000000000000000000000000000000000001dcd6500';
        bytes memory signature = hex'43417905e34b4c0f581dd4162ed6b84805e830ad8a3ae9707d3e499fd95338f035087628f01c6a0583690e0b68cb014928cd64ab1069a6a64d225b9ab8ca21f21b';

        vm.prank(testValidator);
        amb.submitSignature(signature, messageData);

        // Collect the signature to call ForeignAMB.executeSignature();
        bytes memory signatures = ambBridgeHelper.getSignatures(messageData);

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

    function test_setCustomTokenPair() public {
        address EURC = vm.envAddress("EURC"); //EURC on Ethereum
        vm.prank(omnibridge.owner());
        vm.expectEmit(address(omnibridge));
        emit NewTokenRegistered(EURC, address(eurcE));
        omnibridge.setCustomTokenAddressPair(EURC, address(eurcE));

    }

    function test_mintEURC() public {

        address newMinter = makeAddr("newMinter");
        address newController = makeAddr("newController");
        uint256 mintingAllowance = 1_000_000e6;

        vm.prank(masterMinter.owner());
        vm.expectEmit(address(masterMinter));
        emit ControllerConfigured(newController, newMinter);
        masterMinter.configureController(newController,newMinter);

        vm.prank(newController);
        vm.expectEmit(address(masterMinter));
        emit MinterConfigured(newController, newMinter, mintingAllowance);
        masterMinter.configureMinter(mintingAllowance);

        vm.prank(newMinter);
        eurcE.mint(sender,mintingAllowance);


    }

    function test_relayTokens() public {
        setCustomTokenPairAndBridgeLimit();
        uint256 amountToTransfer = 500e6;

        uint256 senderBalanceBefore = eurcE.balanceOf(sender);
        uint256 omniBridgeBalanceBefore = eurcE.balanceOf(address(omnibridge));

        vm.startPrank(sender);
        eurcE.approve(address(omnibridge), eurcE.balanceOf(sender));
        omnibridge.relayTokens(IERC677(address(eurcE)),amountToTransfer);
        vm.stopPrank();

        assertEq(eurcE.balanceOf(sender), senderBalanceBefore - amountToTransfer);
        assertEq(eurcE.balanceOf(address(omnibridge)), omniBridgeBalanceBefore); // EURC is burn

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
    function setDefaultFee() public {
        bytes32  HOME_TO_FOREIGN_FEE = 0x741ede137d0537e88e0ea0ff25b1f22d837903dbbee8980b4a06e8523247ee26; // keccak256(abi.encodePacked("homeToForeignFee"))
        // bytes32  FOREIGN_TO_HOME_FEE = 0x03be2b2875cb41e0e77355e802a16769bb8dfcf825061cde185c73bf94f12625; // keccak256(abi.encodePacked("foreignToHomeFee"))

        address feeManagerAddress = omnibridge.feeManager();
        IOmnibridgeFeeManager feeManager;
        feeManager = IOmnibridgeFeeManager(feeManagerAddress);
        address feeManagerOwner = feeManager.owner();

        vm.startPrank(feeManagerOwner);
        // default value of HOME_TO_FOREIGN_FEE =  1000000000000000
        feeManager.setFee(HOME_TO_FOREIGN_FEE, address(0), 0);
        // default value of FOREIGN_TO_HOME_FEE = 0
        // feeManager.setFee(FOREIGN_TO_HOME_FEE, address(0), 0);
        vm.stopPrank();

    }

    function setNewValidator() public {
        address bridgeValidatorOwner = bridgeValidators.owner();
        vm.startPrank(bridgeValidatorOwner);
        bridgeValidators.setRequiredSignatures(1);
        bridgeValidators.addValidator(testValidator);
        vm.stopPrank();
    }
    function setCustomTokenPairAndBridgeLimit() public {
        address bridgeOwner = omnibridge.owner();
        address EURC = vm.envAddress("EURC"); //EURC on Ethereum

        vm.startPrank(bridgeOwner);
        omnibridge.setCustomTokenAddressPair(EURC, address(eurcE));
        assertEq(false,omnibridge.isTokenRegistered(address(eurcE)));

        uint256 defaultDailyLimit = omnibridge.dailyLimit(address(0));
        uint256 defaultExecutionDailyLimit = omnibridge.executionDailyLimit(address(0));

        // reset default dailyLimit and executionDailyLimit
        vm.startPrank(omnibridge.owner());
        omnibridge.setDailyLimit(address(0),defaultDailyLimit*10);
        omnibridge.setExecutionDailyLimit(address(0),defaultExecutionDailyLimit*10);
        vm.stopPrank();
    }

    function setUpForHome() public {
        bytes memory messageData = hex'000500004ac82b41bd819dd871590b510316f2385cb196fb000000000002385388ad09518695c6c3712ac10a214be5109a655671f6a78083ca3e2a662d6dd1703c939c8ace2e268d001e848001010001642ae87cdd0000000000000000000000001abaea1f7c830bd89acc67ec4af516284b1bc33c00000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681000000000000000000000000000000000000000000000000000000001dcd650000000000000000000000000000000000000000000000000000000000000000094575726f20436f696e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044555524300000000000000000000000000000000000000000000000000000000'; // required from ethereumTest.t.sol
        setDefaultFee();
        setNewValidator();
        setCustomTokenPairAndBridgeLimit();
        vm.startPrank(testValidator);
        amb.executeAffirmation(messageData);
        vm.stopPrank();
    }

}