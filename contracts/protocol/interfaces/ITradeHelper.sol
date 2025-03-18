// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITradeHelper {
    struct Route {
        address from;
        address to;
        bool stable;
    }

    function getAmountOutStable(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 amount);

    function getAmountOutVolatile(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 amount);

    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 amount, bool stable);

    function getAmountsOut(uint256 amountIn, Route[] memory routes) external view returns (uint256[] memory amounts);

    function getAmountInStable(
        uint256 amountOut,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 amountIn);

    function poolFor(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (address pool);

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);

    function factory() external view returns (address);
}
