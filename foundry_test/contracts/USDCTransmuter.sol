pragma solidity >=0.4.24 <0.9.0;
pragma experimental ABIEncoderV2;

import {FiatTokenV2_2} from "../../contracts/v2/FiatTokenV2_2.sol";
import {IPermittableToken} from "../interface/IPermittableToken.sol";
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

    constructor(address _usdc, address _usdce, address _omnibridge)public{
        usdc = IPermittableToken(_usdc);
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
        require(token == address(usdc), "only USDC from Ethereum!");

        // decode input data
        (address depositor) = abi.decode(data,(address));
        require(depositor!=address(0),"invalid depositor address");
        depositAmount[depositor]+=value;
        usdce.mint(depositor, value);
        emit Deposit(depositor,value);

    }


    // deposit USDC and get USDC.e
      function deposit(address depositor, uint256 amount) external  {
        require(amount>0, "invalid deposit amount!");
        depositAmount[depositor]+=amount;
        // check if transferFrom return true
        require(usdc.transferFrom(depositor, address(this),amount), "failed to transfer!");
        // check if mint return true
        require(usdce.mint(depositor, amount),"failed to mint!");
        emit Withdraw(depositor, amount);
    }

    // deposit USDC and get USDC.e
    function deposit(uint256 amount) external {
        require(amount>0, "invalid deposit amount!");
        depositAmount[msg.sender]+=amount;
        // check if transferFrom return true
        require(usdc.transferFrom(msg.sender, address(this),amount), "failed to transfer!");
        // check if mint return true
        require(usdce.mint(msg.sender, amount),"failed to mint!");
        emit Withdraw(msg.sender, amount);
    }

    // withdraw USDC
    function withdraw (uint256 amount) external {
        require(depositAmount[msg.sender]>=amount && usdc.balanceOf(address(this))>=amount, "withdrawal amount exceeded!");
        depositAmount[msg.sender] -=amount;
        require(usdc.transfer(msg.sender,amount),"failed to transfer!");
        usdce.burn(amount);
        emit Withdraw(msg.sender, amount);
    }

    // withdraw USDC
    function withdrawal(address withdrawer, uint256 amount) external {
        require(depositAmount[withdrawer]>=amount && usdc.balanceOf(address(this))>=amount, "withdrawal amount exceeded!");
        depositAmount[withdrawer] -=amount;
        require(usdc.transfer(withdrawer,amount),"failed to transfer!");
        usdce.burn(amount);
        emit Withdraw(withdrawer, amount);
    }



}