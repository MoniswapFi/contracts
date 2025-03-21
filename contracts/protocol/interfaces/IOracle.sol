pragma solidity ^0.8.0;

interface IOracle {
    /// @notice This is the only function from the oracle that we need
    function getAverageValueInUSD(address _token, uint256 _value) external view returns (uint256, int256);
}
