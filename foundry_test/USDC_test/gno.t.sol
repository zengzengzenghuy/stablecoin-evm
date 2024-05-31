// SPDX-License-Identifier: GPL-3.0
pragma experimental ABIEncoderV2;
pragma solidity >=0.6.12 <0.9.0;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdUtils.sol";
import { IOmnibridge, IERC677 } from "../interface/IOmnibridge.sol";
import { IAMB } from "../interface/IAMB.sol";
import { IBridgeValidators } from "../interface/IBridgeValidators.sol";
import { IMasterMinter } from "../interface/IMasterMinter.sol";
import { FiatTokenV2_2 } from "../../contracts/v2/FiatTokenV2_2.sol";
import { FiatTokenProxy } from "../../contracts/v1/FiatTokenProxy.sol";
import { USDCTransmuter } from "../../contracts/USDCTransmuter.sol";
import { MasterMinter } from "../../contracts/minting/MasterMinter.sol";

contract gnoTest is Test {
    IOmnibridge omnibridge;
    IAMB amb;
    IBridgeValidators bridgeValidatorContract;
    FiatTokenV2_2 usdc;
    FiatTokenV2_2 usdcE;
    IERC677 usdcOnXdai;
    IMasterMinter masterMinter;
    address senderFromETH;
    address senderFromGC;
    address testValidator;
    uint256 amount;
    USDCTransmuter usdcTransmuter;

    function setUp() public {
        omnibridge = IOmnibridge(vm.envAddress("HOME_OMNIBRIDGE"));
        amb = IAMB(vm.envAddress(("HOME_AMB")));
        bridgeValidatorContract = IBridgeValidators(
            vm.envAddress("HOME_VALIDATOR_CONTRACT")
        );
        usdc = FiatTokenV2_2(vm.envAddress("USDC_ON_ETH")); // USDC on Ethereum
        usdcE = FiatTokenV2_2(vm.envAddress("USDCE")); // USDC.e
        usdcOnXdai = IERC677(vm.envAddress("USDC_ON_GNO")); // old USDC on xDAI
        testValidator = vm.envAddress("VALIDATOR_ADDRESS");
        usdcTransmuter = USDCTransmuter(vm.envAddress("USDC_TRANSMUTER"));
        masterMinter = IMasterMinter(vm.envAddress("USDCE_MASTER_MINTER"));
        senderFromETH = 0xD6153F5af5679a75cC85D8974463545181f48772; // USDC holder on Ethereum, for testing only
        senderFromGC = makeAddr("senderFromGC");
        amount = 1e10; // 1e6 USDC

        vm.startPrank(masterMinter.owner());
        // set usdc transmuter as USDC.e minter
        masterMinter.configureController(
            masterMinter.owner(),
            address(usdcTransmuter)
        );
        // grant transtermuter minting allowance
        masterMinter.configureMinter(1e30);
        vm.stopPrank();

        setNewValidator();
    }

    function test_receiveUSDCFromETH() public {
        string memory root = vm.projectRoot();
        string memory path = string(
            abi.encodePacked(
                root,
                "/foundry_test/USDC_test/test_output/GNO_input.json"
            )
        );
        string memory json = vm.readFile(path);
        bytes memory messageInBytes = vm.parseJson(json, ".data");
        bytes memory message = abi.decode(messageInBytes, (bytes));

        uint256 senderUSDCEBalanceBefore = usdcE.balanceOf(senderFromETH);
        uint256 senderUSDCBalanceBefore = usdcOnXdai.balanceOf(senderFromETH);
        uint256 transmuterUSDCEBalanceBefore = usdcE.balanceOf(
            address(usdcTransmuter)
        );
        uint256 transmuterUSDCBalanceBefore = usdcOnXdai.balanceOf(
            address(usdcTransmuter)
        );

        vm.prank(testValidator);
        amb.executeAffirmation(message);

        uint256 senderUSDCEBalanceAfter = usdcE.balanceOf(senderFromETH);
        uint256 senderUSDCBalanceAfter = usdcOnXdai.balanceOf(senderFromETH);
        uint256 transmuterUSDCEBalanceAfter = usdcE.balanceOf(
            address(usdcTransmuter)
        );
        uint256 transmuterUSDCBalanceAfter = usdcOnXdai.balanceOf(
            address(usdcTransmuter)
        );

        // Check user balance
        // User is expected to get USDC.e
        assertEq(
            senderUSDCEBalanceBefore + amount,
            senderUSDCEBalanceAfter,
            "user's USDC.e balance mismatch"
        );

        assertEq(
            senderUSDCBalanceBefore,
            senderUSDCBalanceAfter,
            "user's USDC balance mismatch"
        );
        // Check transmuter balance
        // Transmuter is expected to lock USDC on xDAI
        assertEq(
            transmuterUSDCEBalanceBefore,
            transmuterUSDCEBalanceAfter,
            "bridge's USDC.e balance mismatch"
        );
        assertEq(
            transmuterUSDCBalanceBefore + amount,
            transmuterUSDCBalanceAfter,
            "bridge's USDC balance mismatch"
        );
    }

    function test_relayUSDCEFromGC() public {
        // To relay USDC.e from GC and get USDC on ETH
        // 1. swap USDC.e to USDC on xDAI in transmuter contract (full testing in USDCTransmuter.t.sol)
        // 2. approve Omnibridge
        // 3. call Omnibridge.relayTokens
        // swap USDC.e to USDC on xDAI

        // since it is not possible to use deal() for USDC, in this test we suppose user has USDC on xDAI and swap for USDC.e first
        // then swap back to USDC on xDAI before bridging
        // https://github.com/foundry-rs/foundry/issues/7137

        deal(address(usdcOnXdai), senderFromGC, amount);
        vm.startPrank(senderFromGC);
        usdcOnXdai.approve(address(usdcTransmuter), amount);
        usdcTransmuter.deposit(amount);
        usdcE.approve(address(usdcTransmuter), amount);
        usdcTransmuter.withdraw(amount);
        vm.stopPrank();

        uint256 senderUSDCBalanceBefore = usdcOnXdai.balanceOf(senderFromGC);
        uint256 bridgeUSDCBalanceBefore = usdcOnXdai.balanceOf(
            address(omnibridge)
        );

        assertEq(
            senderUSDCBalanceBefore,
            amount,
            "user's USDC balance mismatch"
        );
        vm.startPrank(senderFromGC);
        // Step 2: approve Omnibridge
        usdcOnXdai.approve(address(omnibridge), amount);
        // Step 3: call relayTokens
        omnibridge.relayTokens(usdcOnXdai, amount);
        vm.stopPrank();

        uint256 senderUSDCBalanceAfter = usdcOnXdai.balanceOf(senderFromGC);
        uint256 bridgeUSDCBalanceAfter = usdcOnXdai.balanceOf(
            address(omnibridge)
        );

        assertEq(
            senderUSDCBalanceBefore - amount,
            senderUSDCBalanceAfter,
            "user's USDC balance mismatch"
        );
        assertEq(
            bridgeUSDCBalanceBefore,
            bridgeUSDCBalanceAfter,
            "bridge's USDC balance mismatch"
        );
    }

    // ================= Helper ==============================

    function setNewValidator() public {
        address bridgeValidatorOwner = bridgeValidatorContract.owner();
        vm.startPrank(bridgeValidatorOwner);
        bridgeValidatorContract.setRequiredSignatures(1);
        bridgeValidatorContract.addValidator(testValidator);
        vm.stopPrank();
    }
}
