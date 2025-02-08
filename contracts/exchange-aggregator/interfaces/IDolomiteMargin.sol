pragma solidity ^0.8.0;

interface IDolomiteMargin {
    struct Price {
        uint256 value;
    }

    function getMarketIdByTokenAddress(address token) external view returns (uint256);

    function getMarketPrice(uint256 marketId) external view returns (Price memory);
}
