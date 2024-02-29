pragma solidity >=0.6.0;

interface IOmnibridge {
    function relayTokens(IERC677 token,uint256 _value) external;

    function setCustomTokenAddressPair(address _nativeToken, address _bridgedToken) external;

    function owner() external view returns (address);
    function maxPerTx(address _token) external view returns (uint256);
    function setMaxPerTx(address _token, uint256 _maxPerTx) external;
    function executionMaxPerTx(address _token) external view returns (uint256);
    function setExecutionMaxPerTx(address _token, uint256 _maxPerTx) external;

    function isTokenRegistered(address _token) external view returns (bool);
    function feeManager() external view returns(address);
}

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC677 is IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value, bytes data);

    function transferAndCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool);

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
}
