// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPool} from "../interfaces/IPool.sol";
import {IPoolFactory} from "../interfaces/factories/IPoolFactory.sol";
import {PoolFees} from "../PoolFees.sol";
import {ITradeHelper} from "../interfaces/ITradeHelper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TradeHelper is ITradeHelper {
    address public immutable factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "TradeHelper: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "TradeHelper: ZERO_ADDRESS");
        require(token1 != address(0), "TradeHelper: ZERO_ADDRESS");
    }

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1) {
        return _sortTokens(tokenA, tokenB);
    }

    function _poolFor(
        address tokenA,
        address tokenB,
        bool stable
    ) internal view returns (address pool) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        pool = IPoolFactory(factory).getPool(token0, token1, stable);
    }

    function poolFor(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (address pool) {
        pool = _poolFor(tokenA, tokenB, stable);
    }

    function _calculate_k(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * ((((y * y) / 1e18) * y) / 1e18)) / 1e18 + (((((x * x) / 1e18) * x) / 1e18) * y) / 1e18;
    }

    function _calculate_deriv(uint256 x, uint256 y) internal pure returns (uint256) {
        return (3 * y * ((x * x) / 1e18)) / 1e18 + ((((y * y) / 1e18) * y) / 1e18);
    }

    function getAmountOutStable(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256 amount) {
        address pool = _poolFor(tokenIn, tokenOut, true);
        return (IPoolFactory(factory).isPool(pool)) ? IPool(pool).getAmountOut(amountIn, tokenIn) : 0;
    }

    function getAmountOutVolatile(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256 amount) {
        address pool = _poolFor(tokenIn, tokenOut, false);
        return (IPoolFactory(factory).isPool(pool)) ? IPool(pool).getAmountOut(amountIn, tokenIn) : 0;
    }

    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256 amount, bool stable) {
        uint256 amountStable = getAmountOutStable(amountIn, tokenIn, tokenOut);
        uint256 amountVolatile = getAmountOutVolatile(amountIn, tokenIn, tokenOut);
        return amountStable > amountVolatile ? (amountStable, true) : (amountVolatile, false);
    }

    function getAmountsOut(uint256 amountIn, ITradeHelper.Route[] memory routes)
        public
        view
        returns (uint256[] memory amounts)
    {
        require(routes.length >= 1, "TradeHelper: INVALID_PATH");
        amounts = new uint256[](routes.length + 1);
        amounts[0] = amountIn;
        for (uint256 i = 0; i < routes.length; i++) {
            (amounts[i + 1], ) = getAmountOut(amounts[i], routes[i].from, routes[i].to);
        }
    }

    function getAmountInStable(
        uint256 amountOut,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256 amountIn) {
        address pool = _poolFor(tokenIn, tokenOut, true);

        amountIn = type(uint256).max;
        if (IPoolFactory(factory).isPool(pool)) {
            IPool p = IPool(pool);

            uint256 decimalsIn = 10**ERC20(tokenIn).decimals();
            uint256 decimalsOut = 10**ERC20(tokenOut).decimals();

            uint256 reserveIn = (((tokenIn == p.token0()) ? p.reserve0() : p.reserve1()) * 1e18) / decimalsIn;
            uint256 reserveOut = (((tokenOut == p.token0()) ? p.reserve0() : p.reserve1()) * 1e18) / decimalsOut;
            uint256 output = (amountOut * 1e18) / decimalsOut;

            uint256 y_1 = reserveOut + output;

            uint256 old_k = _calculate_k(reserveIn, reserveOut);
            uint256 x_1 = reserveIn;

            for (uint256 i = 0; i < 255; i++) {
                uint256 prev_x = x_1;
                uint256 new_k = _calculate_k(x_1, y_1);

                if (new_k < old_k) {
                    uint256 dx = ((old_k - new_k) * 1e18) / _calculate_deriv(x_1, y_1);

                    x_1 = x_1 + dx;
                } else {
                    uint256 dx = ((new_k - old_k) * 1e18) / _calculate_deriv(x_1, y_1);

                    x_1 = x_1 - dx;
                }

                //Check if we have found the result
                if (x_1 > prev_x) {
                    if (x_1 - prev_x <= 1) {
                        break;
                    }
                } else {
                    if (prev_x - x_1 <= 1) {
                        break;
                    }
                }
            }
            //amountIn = (new_x_amount - old_x_amount) * (1+fees)
            uint256 amountInNoFees = (((reserveIn - x_1) * decimalsOut) / 1e18);
            amountIn = (amountInNoFees * (10000 + IPoolFactory(factory).getFee(pool, true))) / 10000;
        }
    }

    function getAmountInVolatile(
        uint256 amountOut,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256 amountIn) {
        address pool = _poolFor(tokenIn, tokenOut, false);
        amountIn = type(uint256).max;

        if (IPoolFactory(factory).isPool(pool)) {
            IPool p = IPool(pool);

            uint256 reserveIn = (tokenIn == p.token0()) ? p.reserve0() : p.reserve1();
            uint256 reserveOut = (tokenOut == p.token0()) ? p.reserve0() : p.reserve1();

            amountIn =
                (((amountOut * reserveIn) / (reserveOut - amountOut)) *
                    (10000 + IPoolFactory(factory).getFee(pool, false))) /
                10000;
        }
    }

    function getAmountIn(
        uint256 amountOut,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256 amount, bool stable) {
        uint256 amountStable = getAmountInStable(amountOut, tokenIn, tokenOut);
        uint256 amountVolatile = getAmountInVolatile(amountOut, tokenIn, tokenOut);
        return amountStable < amountVolatile ? (amountStable, true) : (amountVolatile, false);
    }

    function getAmountsIn(uint256 amountOut, ITradeHelper.Route[] memory routes)
        public
        view
        returns (uint256[] memory amounts)
    {
        require(routes.length >= 1, "TradeHelper: INVALID_PATH");
        amounts = new uint256[](routes.length + 1);
        amounts[routes.length] = amountOut;
        for (uint256 i = routes.length - 1; i >= 0; i--) {
            (amounts[i], ) = getAmountIn(amounts[i + 1], routes[i].from, routes[i].to);
        }
    }
}
