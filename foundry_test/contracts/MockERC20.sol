pragma solidity 0.6.12;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 initialSupply,
        uint8 decimals,
        address receiver
    ) public ERC20(tokenName, tokenSymbol) {
        _mint(receiver, initialSupply);
        _setupDecimals(decimals);
    }
}
