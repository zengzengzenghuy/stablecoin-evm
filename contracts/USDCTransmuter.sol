// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.0;

import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { FiatTokenV2_2 } from "./v2/FiatTokenV2_2.sol";
import { IPermittableToken } from "./interface/IPermittableToken.sol";
import { IOmnibridge, IERC677 } from "./interface/IOmnibridge.sol";

interface IERC20Receiver {
    function onTokenBridged(
        address token,
        uint256 value,
        bytes calldata data
    ) external;
}

/// @title USDCTransmuter contract
/// @author zeng
/// @notice This contract allows user to swap between USDC.e and USDC on xDAI, bridge USDC on ETH <-> USDC.e on GC
contract USDCTransmuter is IERC20Receiver, ReentrancyGuard {
    event Withdraw(address indexed depositor, uint256 indexed amount);
    event Deposit(address indexed depositor, uint256 indexed amount);
    IPermittableToken usdc;
    FiatTokenV2_2 usdce;
    address omnibridge;
    address USDC_ON_GC = 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83;

    constructor(address _usdce, address _omnibridge) public {
        usdc = IPermittableToken(USDC_ON_GC);
        usdce = FiatTokenV2_2(_usdce);
        omnibridge = _omnibridge;
    }

    /// @notice called by Omnibridge when USDC is bridged from ETH
    /// @dev USDC on xDAI is locked to this contract, and mint equivalent amount of USDC.e to depositor
    /// @param token USDC on xDAI address
    /// @param value amount of USDC.e to mint
    /// @param data data from relayTokensAndCall (depositor address)
    /// TODO: should be removed to suit new Omnibridge implementation
    function onTokenBridged(
        address token,
        uint256 value,
        bytes calldata data
    ) external override {
        require(msg.sender == omnibridge, "only Omnibridge!");
        require(token == USDC_ON_GC, "only USDC from Omnibridge!");

        // decode input data
        address depositor = abi.decode(data, (address));
        require(depositor != address(0), "invalid depositor address");

        require(usdce.mint(depositor, value), "fail to mint");
        emit Deposit(depositor, value);
    }

    /// @notice send USDC.e from GnosisChain, and receive USDC on Ethereum
    /// @dev USDC.e is burn from this contract, and USDC on xDA is relayed.
    /// @param receiverOnETH receiver of USDC on Ethereum
    /// @param amount amount of USDC.e to bridge
    /// TODO: should be removed to suit new Omnibridge implementation
    function bridgeUSDCE(address receiverOnETH, uint256 amount)
        external
        nonReentrant
    {
        require(
            receiverOnETH != address(0) && amount != 0,
            "invalid address or amount"
        );

        usdce.transferFrom(msg.sender, address(this), amount);
        usdce.burn(amount);
        IERC677(address(usdc)).increaseAllowance(omnibridge, amount);
        IOmnibridge(omnibridge).relayTokens(
            IERC677(address(usdc)),
            receiverOnETH,
            amount
        );
    }

    /// @notice deposit USDC on xDAI and get USDC.e
    /// @dev USDC on xDAI is transferred into this contract, and USDC.e is minted to msg.sender
    /// @param amount amount of USDC on xDAI to deposit into this contract
    function deposit(uint256 amount) external nonReentrant {
        _deposit(msg.sender, amount);
    }

    /// @notice send USDC.e and withdraw USDC on xDAI from this contract
    /// @dev USDc.e is transferred and burn from this contract, USDC on xDAI is transferred to msg.sender
    /// @param amount amount of USDC on xDAI to withdraw
    function withdraw(uint256 amount) external nonReentrant {
        _withdraw(msg.sender, amount);
    }

    function _withdraw(address withdrawer, uint256 amount) internal {
        require(
            usdc.balanceOf(address(this)) >= amount,
            "withdrawal amount exceeded!"
        );

        require(
            usdce.transferFrom(withdrawer, address(this), amount),
            "USDC.e transferFrom unsuccessful"
        );
        usdce.burn(amount);

        require(usdc.transfer(withdrawer, amount), "failed to transfer!");
        emit Withdraw(withdrawer, amount);
    }

    function _deposit(address depositor, uint256 amount) internal {
        require(amount > 0, "invalid deposit amount!");

        // check if transferFrom return true
        require(
            usdc.transferFrom(depositor, address(this), amount),
            "failed to transfer!"
        );
        // check if mint return true
        require(usdce.mint(depositor, amount), "failed to mint!");
        emit Deposit(depositor, amount);
    }
}
