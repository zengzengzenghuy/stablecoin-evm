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
import {USDCTransmuter} from "../contracts/USDCTransmuter.sol";
import {IPermittableToken} from "../interface/IPermittableToken.sol";
import {MasterMinter} from "../../contracts/minting/MasterMinter.sol";

contract USDCTransmuterTest is Test {
    USDCTransmuter usdcTransmuter;
    IPermittableToken usdc;
    FiatTokenV2_2 usdce;
    MasterMinter masterMinter;
    address depositor;

    function setUp() public {
        usdc = IPermittableToken(0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83); // USDC on Gnosis
        usdce = FiatTokenV2_2(0x906cce67ff158893D982C681aBFA1EE845C23eDc); //USDC.e on Gnosis
        address omnibridge = 0xf6A78083ca3e2a662D6dd1703c939c8aCE2e268d;

        address owner = 0x458cD345B4C05e8DF39d0A07220feb4Ec19F5e6f;
        masterMinter = MasterMinter(0x55715Acb53a53332Fc2EBEC4a4ce50ab6086C4E0);

        usdcTransmuter = new USDCTransmuter(address(usdc), address(usdce), omnibridge);
        depositor = makeAddr("depositor");
        deal(address(usdc),depositor, 1e10);

        assertEq(usdc.balanceOf(depositor), 1e10);
        // configure minter
        vm.startPrank(owner);

        masterMinter.configureController(owner, address(usdcTransmuter));
        masterMinter.configureMinter(1e20);

        vm.stopPrank();

    }

    function test_deposit() public {
        uint256 amount = 1e10;
            assertEq(usdc.balanceOf(depositor),amount);

            vm.startPrank(depositor);

            usdc.approve(address(usdcTransmuter),amount);
            usdcTransmuter.deposit(amount);

            vm.stopPrank();

            assertEq(usdc.balanceOf(address(usdcTransmuter)),amount);
            assertEq(usdce.balanceOf(depositor),amount);

    }

    function testFuzz_deposit(uint256 amount) public{
        // amount > 0 , amount < minterAllowance
        vm.assume(amount > 0 && amount <1e20);
        deal(address(usdc),depositor, amount);


        vm.startPrank(depositor);

        usdc.approve(address(usdcTransmuter),amount);
        usdcTransmuter.deposit(amount);

        vm.stopPrank();

        assertEq(usdc.balanceOf(address(usdcTransmuter)),amount);
        assertEq(usdce.balanceOf(depositor),amount);
    }

    function test_withdrawal() public {
            vm.startPrank(depositor);

            usdc.approve(address(usdcTransmuter),1e10);
            usdcTransmuter.deposit(1e10);
            usdce.approve(address(usdcTransmuter),1e8);
            usdcTransmuter.withdraw(1e8);

            vm.stopPrank();

            assertEq(usdc.balanceOf(depositor),1e8);
            assertEq(usdce.balanceOf(depositor),1e10-1e8);
            assertEq(usdc.balanceOf(address(usdcTransmuter)),1e10-1e8);

    }
        function testFuzz_withdrawal(uint256 depositAmount, uint256 withdrawAmount) public {
            vm.assume(depositAmount > 0 && depositAmount <1e20 && withdrawAmount > 0 && withdrawAmount <= depositAmount);
            deal(address(usdc),depositor, depositAmount);
            vm.startPrank(depositor);

            usdc.approve(address(usdcTransmuter),depositAmount);
            usdcTransmuter.deposit(depositAmount);
            usdce.approve(address(usdcTransmuter),withdrawAmount);
            usdcTransmuter.withdraw(withdrawAmount);

            vm.stopPrank();

            assertEq(usdc.balanceOf(depositor),withdrawAmount);
            assertEq(usdce.balanceOf(depositor),depositAmount-withdrawAmount);
            assertEq(usdc.balanceOf(address(usdcTransmuter)),depositAmount-withdrawAmount);

    }



}