// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {FiatTokenV2_2} from "./v2/FiatTokenV2_2.sol";
import {IPermittableToken} from "./interface/IPermittableToken.sol";
import {IOmnibridge,IERC677} from "./interface/IOmnibridge.sol";
interface IERC20Receiver {
    function onTokenBridged(
        address token,
        uint256 value,
        bytes calldata data
    ) external;
}
contract USDCTransmuter is IERC20Receiver, ReentrancyGuard {

    event Withdraw(address indexed depositor, uint256 indexed amount);
    event Deposit(address indexed depositor, uint256 indexed amount);
    IPermittableToken usdc;
    FiatTokenV2_2 usdce;
    address omnibridge;
    address USDC_ON_GC = 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83;

    constructor(address _usdce, address _omnibridge)public{
        usdc = IPermittableToken(USDC_ON_GC);
        usdce = FiatTokenV2_2(_usdce);
        omnibridge = _omnibridge;
    }


    // called by Omnibridge after minting token for Transmuter
    // mint USDC.e to depositor
    function onTokenBridged(
        address token,
        uint256 value,
        bytes calldata data
    ) external override{
        require(msg.sender == omnibridge, "only Omnibridge!");
        require(token == USDC_ON_GC, "only USDC from Omnibridge!");

        // decode input data
        (address depositor) = abi.decode(data,(address));
        require(depositor!=address(0),"invalid depositor address");

        require(usdce.mint(depositor, value),"fail to mint");
        emit Deposit(depositor,value);

    }


    // called by user who wants to send USDC.e from GnosisChain, and receive USDC on Ethereum
    function bridgeUSDCE(address receiverOnETH, uint256 amount) external nonReentrant{
        require(receiverOnETH!=address(0) && amount!=0, "invalid address or amount");

        usdce.transferFrom(msg.sender,address(this),amount);
        usdce.burn(amount);
        IERC677(address(usdc)).increaseAllowance(omnibridge,amount);
        IOmnibridge(omnibridge).relayTokens(IERC677(address(usdc)),receiverOnETH,amount);

    }

    // deposit USDC and get USDC.e
    function deposit(uint256 amount) external nonReentrant{
        _deposit(msg.sender, amount);
    }

    // withdraw USDC
    function withdraw (uint256 amount) external nonReentrant{
        _withdraw(msg.sender, amount);
    }

    function _withdraw(address withdrawer, uint256 amount) internal {
        require(usdc.balanceOf(address(this))>=amount, "withdrawal amount exceeded!");

        require(usdce.transferFrom(withdrawer, address(this),amount),"USDC.e transferFrom unsuccessful");
        usdce.burn(amount);

        require(usdc.transfer(withdrawer,amount),"failed to transfer!");
        emit Withdraw(withdrawer, amount);
    }

    function _deposit(address depositor, uint256 amount) internal {
        require(amount>0, "invalid deposit amount!");

        // check if transferFrom return true
        require(usdc.transferFrom(depositor, address(this),amount), "failed to transfer!");
        // check if mint return true
        require(usdce.mint(depositor, amount),"failed to mint!");
        emit Deposit(depositor, amount);
    }


}