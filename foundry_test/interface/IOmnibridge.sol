pragma solidity >=0.6.0;

interface IOmnibridge {
    function relayTokens(IERC677 token, uint256 _value) external;

    function relayTokens(
        IERC677 token,
        address _receiver,
        uint256 _value
    ) external;

    function relayTokensAndCall(
        IERC677 token,
        address _receiver,
        uint256 _value,
        bytes memory _data
    ) external;

    function setCustomTokenAddressPair(
        address _nativeToken,
        address _bridgedToken
    ) external;

    function owner() external view returns (address);

    function maxPerTx(address _token) external view returns (uint256);

    function minPerTx(address _token) external view returns (uint256);

    function setMaxPerTx(address _token, uint256 _maxPerTx) external;

    function executionMaxPerTx(address _token) external view returns (uint256);

    function setExecutionMaxPerTx(address _token, uint256 _maxPerTx) external;

    function dailyLimit(address _token) external view returns (uint256);

    function setDailyLimit(address _token, uint256 _dailyLimit) external;

    function executionDailyLimit(address _token)
        external
        view
        returns (uint256);

    function setExecutionDailyLimit(address _token, uint256 _dailyLimit)
        external;

    function isTokenRegistered(address _token) external view returns (bool);

    function feeManager() external view returns (address);

    function getCurrentDay() external view returns (uint256);

    function totalSpentPerDay(address _token, uint256 _day)
        external
        view
        returns (uint256);
}

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC677 is IERC20 {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value,
        bytes data
    );

    function mint(address _to, uint256 _amount) external returns (bool);

    function transferAndCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool);

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool);

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool);
}
