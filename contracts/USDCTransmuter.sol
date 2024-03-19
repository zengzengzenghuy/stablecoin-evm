// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.0;

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
contract USDCTransmuter is IERC20Receiver {
    mapping(address=>uint256) depositAmount;
    event Withdraw(address indexed depositor, uint256 indexed amount);
    event Deposit(address indexed depositor, uint256 indexed amount);
    IPermittableToken usdc;
    FiatTokenV2_2 usdce;
    address omnibridge;
    address USDC_ON_ETH = 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83;

    constructor(address _usdce, address _omnibridge)public{
        usdc = IPermittableToken(USDC_ON_ETH);
        usdce = FiatTokenV2_2(_usdce);
        omnibridge = _omnibridge;
    }

    modifier onlyOmnibridge{
        require(msg.sender == omnibridge, "only Omnibridge!");
        _;
    }

    // called by Omnibridge after minting token for Transmuter
    // mint USDC.e to depositor
    function onTokenBridged(
        address token,
        uint256 value,
        bytes calldata data
    ) external override onlyOmnibridge{
        require(token == USDC_ON_ETH, "only USDC from Ethereum!");

        // decode input data
        (address depositor) = abi.decode(data,(address));
        require(depositor!=address(0),"invalid depositor address");
        depositAmount[depositor]+=value;
        require(usdce.mint(depositor, value),"fail to mint");
        emit Deposit(depositor,value);

    }


    // call by user who wants to send USDC.e from GnosisChain, and receive USDC on Ethereum
    function bridgeUSDCE(address receiverOnETH, uint256 amount) external {
        depositAmount[msg.sender]-=amount;
        usdce.transferFrom(msg.sender,address(this),amount);

        usdce.burn(amount);
        IERC677(address(usdc)).increaseAllowance(omnibridge,amount);
        IOmnibridge(omnibridge).relayTokens(IERC677(address(usdc)),receiverOnETH,amount);

    }




    // deposit USDC and get USDC.e
      function deposit(address depositor, uint256 amount) external  {
        _deposit(depositor,amount);
    }

    // deposit USDC and get USDC.e
    function deposit(uint256 amount) external {
        _deposit(msg.sender, amount);
    }

    // withdraw USDC
    function withdraw (uint256 amount) external {
        _withdraw(msg.sender, amount);
    }

    // withdraw USDC
    function withdraw(address withdrawer, uint256 amount) external {
       _withdraw(withdrawer, amount);
    }
    function _withdraw(address withdrawer, uint256 amount) internal {
         require(depositAmount[withdrawer]>=amount && usdc.balanceOf(address(this))>=amount, "withdrawal amount exceeded!");
        depositAmount[withdrawer] -=amount;
        require(usdc.transfer(withdrawer,amount),"failed to transfer!");
         require(usdce.transferFrom(withdrawer, address(this),amount),"USDC.e transferFrom unsuccessful");
        usdce.burn(amount);
        emit Withdraw(withdrawer, amount);
    }

    function _deposit(address depositor, uint256 amount) internal {
        require(amount>0, "invalid deposit amount!");
        depositAmount[depositor]+=amount;
        // check if transferFrom return true
        require(usdc.transferFrom(depositor, address(this),amount), "failed to transfer!");
        // check if mint return true
        require(usdce.mint(depositor, amount),"failed to mint!");
        emit Deposit(depositor, amount);
    }


}