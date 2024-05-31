// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.0;

import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { FiatTokenV2_2 } from "./v2/FiatTokenV2_2.sol";
import { IPermittableToken } from "./interface/IPermittableToken.sol";
import { IOmnibridge, IERC677 } from "./interface/IOmnibridge.sol";

/// @title IERC20Receiver
interface IERC20Receiver {
    /// @notice callback function that will receive USDC on xDAI and mint USDC.e to receiver
    /// @dev relayTokensAndCall is called from Ethereum, with token receiver encoded in data
    /// @dev token receiver need to be decoded and mint $value of USDC.e to receiver
    /// @param token USDC on xDAI
    /// @param value amount of USDC on xDAI relayed
    /// @param data data from relayTokensAndCall
    function onTokenBridged(
        address token,
        uint256 value,
        bytes calldata data
    ) external;
}

/// @title USDCTransmuter contract
/// @author gnosis chain
/// @notice This contract allows user to swap between USDC.e and USDC on xDAI
contract USDCTransmuter is ReentrancyGuard, Ownable, IERC20Receiver {
    event Withdraw(address indexed depositor, uint256 indexed amount);
    event Deposit(address indexed depositor, uint256 indexed amount);

    IPermittableToken usdc;
    FiatTokenV2_2 usdce;
    IOmnibridge homeOmnibridge;
    // USDC created by Omnibridge
    address public USDC_ON_XDAI = 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83;
    // Circle's standard USDC
    address public USDC_E = 0x2a22f9c3b484c3629090FeED35F17Ff8F88f76F0;
    address public HOME_OMNIBRIDGE = 0xf6A78083ca3e2a662D6dd1703c939c8aCE2e268d;
    bool public isEnabled;

    constructor() public {
        usdc = IPermittableToken(USDC_ON_XDAI);
        usdce = FiatTokenV2_2(USDC_E);
        homeOmnibridge = IOmnibridge(HOME_OMNIBRIDGE);
        isEnabled = true;
    }

    /// @inheritdoc	IERC20Receiver
    function onTokenBridged(
        address token,
        uint256 value,
        bytes calldata data
    ) external override {
        require(msg.sender == HOME_OMNIBRIDGE, "only Omnibridge!");
        require(token == USDC_ON_XDAI, "only USDC from Omnibridge!");

        // decode input data
        address receiver = abi.decode(data, (address));
        require(receiver != address(0), "invalid depositor address");

        require(usdce.mint(receiver, value), "fail to mint");
        emit Deposit(receiver, value);
    }

    /// @notice deposit USDC on xDAI and get USDC.e
    /// @dev USDC on xDAI is transferred into this contract, and USDC.e is minted to msg.sender
    /// @param amount amount of USDC on xDAI to deposit into this contract
    function deposit(uint256 amount) external nonReentrant {
        _deposit(msg.sender, amount);
    }

    /// @notice send USDC.e and withdraw USDC on xDAI from this contract
    /// @dev USDC.e is transferred and burn from this contract, USDC on xDAI is transferred to msg.sender
    /// @param amount amount of USDC on xDAI to withdraw
    function withdraw(uint256 amount) external nonReentrant {
        _withdraw(msg.sender, amount);
    }

    /// @notice Disable the transmuter from swapping
    /// @dev set isEnabled to false, and it's a one way operation
    function disableTransmuter() external onlyOwner {
        require(isEnabled, "contract already disabled!");
        isEnabled = false;
    }

    /// @notice bridge the locked USDC on xDAI in Transmuter contract and send it to $address
    ///         receiver suppose to be Circle address or 0 address
    /// @param receiver address that will receive USDC on ETH
    function rebalanceUSDC(address receiver) external onlyOwner {
        uint256 amount = usdc.balanceOf(address(this));
        usdc.approve(HOME_OMNIBRIDGE, amount);
        homeOmnibridge.relayTokens(IERC677(USDC_ON_XDAI), receiver, amount);
    }

    function _withdraw(address withdrawer, uint256 amount) internal {
        require(isEnabled, "contract is not active!");
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
        require(isEnabled, "contract is not active!");
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
