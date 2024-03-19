pragma solidity 0.6.12;

interface IPermittableToken {

    function transferFrom(address _from, address _to, uint256 _value) external returns(bool);
    function transfer(address _to, uint256 _value) external returns(bool);
    function balanceOf(address _who) external view returns (uint256);
    function approve(address _spender, uint256 _value) external returns (bool);
}