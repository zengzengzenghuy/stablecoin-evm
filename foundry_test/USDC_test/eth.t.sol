// SPDX-License-Identifier: GPL-3.0
pragma experimental ABIEncoderV2;
pragma solidity >=0.6.12 <0.9.0;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdUtils.sol";
import { IOmnibridge, IERC677 } from "../interface/IOmnibridge.sol";
import { IAMB } from "../interface/IAMB.sol";
import { IBridgeValidators } from "../interface/IBridgeValidators.sol";
import { FiatTokenV2_2 } from "../../contracts/v2/FiatTokenV2_2.sol";

contract ethTest is Test {
    IOmnibridge omnibridge;
    IAMB amb;
    IBridgeValidators bridgeValidatorContract;
    FiatTokenV2_2 usdc;
    address senderFromETH;
    address senderFromGC;
    address testValidator;
    uint256 amount;
    address usdcTransmuter;

    function setUp() public {
        omnibridge = IOmnibridge(vm.envAddress("FOREIGN_OMNIBRIDGE"));
        amb = IAMB(vm.envAddress(("FOREIGN_AMB")));
        bridgeValidatorContract = IBridgeValidators(
            vm.envAddress("FOREIGN_VALIDATOR_CONTRACT")
        );
        usdc = FiatTokenV2_2(vm.envAddress("USDC_ON_ETH"));
        testValidator = vm.envAddress("VALIDATOR_ADDRESS");
        usdcTransmuter = vm.envAddress("USDC_TRANSMUTER");
        senderFromETH = 0xD6153F5af5679a75cC85D8974463545181f48772; // USDC holder on Ethereum, for testing only
        senderFromGC = makeAddr("senderFromGC");
        amount = 1e10; // 1e6 USDC

        setNewValidator();
    }

    function test_relayTokensAndCallFromETH() public {
        uint256 senderBalanceBefore = usdc.balanceOf(senderFromETH);
        uint256 omnibridgeBalanceBefore = usdc.balanceOf(address(omnibridge));

        vm.startPrank(senderFromETH);
        usdc.approve(address(omnibridge), amount);
        bytes memory data = abi.encode(senderFromETH);
        omnibridge.relayTokensAndCall(
            IERC677(address(usdc)),
            usdcTransmuter,
            amount,
            data
        );
        vm.stopPrank();

        uint256 senderBalanceAfter = usdc.balanceOf(senderFromETH);
        uint256 omnibridgeBalanceAfter = usdc.balanceOf(address(omnibridge));

        assertEq(
            senderBalanceBefore - amount,
            senderBalanceAfter,
            "sender balance mistmatch"
        );
        assertEq(
            omnibridgeBalanceBefore + amount,
            omnibridgeBalanceAfter,
            "omnibridge balance mismatch"
        );
    }

    function test_claimUSDC() public {
        string memory root = vm.projectRoot();
        string memory path = string(
            abi.encodePacked(
                root,
                "/foundry_test/USDC_test/test_output/ETH_input.json"
            )
        );
        string memory json = vm.readFile(path);
        bytes memory messageInBytes = vm.parseJson(json, ".message");
        bytes memory message = abi.decode(messageInBytes, (bytes));
        bytes memory signaturesInBytes = vm.parseJson(
            json,
            ".packedSignatures"
        );
        bytes memory signatures = abi.decode(signaturesInBytes, (bytes));
        uint256 bridgeUSDCBalanceBefore = usdc.balanceOf(address(omnibridge));
        uint256 senderUSDCBalanceBefore = usdc.balanceOf(senderFromGC);
        uint256 mediatorUSDCBalanceBefore = omnibridge.mediatorBalance(
            address(usdc)
        );

        vm.prank(testValidator);
        amb.executeSignatures(message, signatures);

        uint256 bridgeUSDCBalanceAfter = usdc.balanceOf(address(omnibridge));
        uint256 senderUSDCBalanceAfter = usdc.balanceOf(senderFromGC);
        uint256 mediatorUSDCBalanceAfter = omnibridge.mediatorBalance(
            address(usdc)
        );

        // Bridge unlock USDC
        assertEq(
            bridgeUSDCBalanceBefore - amount,
            bridgeUSDCBalanceAfter,
            " bridge's USDC balance mismatch"
        );

        assertEq(
            senderUSDCBalanceBefore + amount,
            senderUSDCBalanceAfter,
            "user's USDC balance mismatch"
        );
        assertEq(
            mediatorUSDCBalanceBefore - amount,
            mediatorUSDCBalanceAfter,
            "mediator's USDC balance mismatch"
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
