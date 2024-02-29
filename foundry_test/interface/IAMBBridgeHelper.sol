pragma solidity >=0.6.0;

interface IAMBBridgeHelper  {


    function getSignatures(bytes calldata _message) external view returns (bytes memory);

    function clean() external;
}
