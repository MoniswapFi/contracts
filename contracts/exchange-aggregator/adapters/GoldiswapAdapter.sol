// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {IGoldiswap} from "../interfaces/IGoldiswap.sol";
import {Adapter} from "../Adapter.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TransferHelpers} from "../../helpers/TransferHelper.sol";

contract GoldiswapAdapter is Adapter {
    address public immutable factory; // This is the same as the Locks token
    address public immutable honey;

    constructor(
        address _factory,
        uint256 _swapGasEstimate,
        address _honey
    ) Adapter("Goldiswap", _swapGasEstimate) {
        factory = _factory;
        honey = _honey;
    }

    function _query(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view override returns (uint256 _amountOut) {
        if (tokenIn != honey && tokenIn != factory) return 0;
        if (tokenOut != honey && tokenOut != factory) return 0;

        IGoldiswap gSwap = IGoldiswap(factory);

        uint256 mp = gSwap.marketPrice(); // 1 Locks = mp Honey

        // If tokenIn is honey, calculate buy
        if (tokenIn == honey) {
            _amountOut = FixedPointMathLib.divWad(amountIn, mp);
        } else {
            // Calculate sell
            _amountOut = FixedPointMathLib.mulWad(amountIn, mp);
        }
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        address to,
        uint256 amountIn,
        uint256 amountOut
    ) internal override {
        require(tokenIn == honey || tokenOut == honey);
        require(tokenIn == factory || tokenOut == factory);

        address token;
        IGoldiswap gSwap = IGoldiswap(factory);
        // If honey, then buy
        if (tokenIn == honey) {
            gSwap.buy(amountOut, amountIn);
            token = honey;
        } else {
            gSwap.sell(amountIn, amountOut);
            token = factory;
        }

        uint256 balance = ERC20(token).balanceOf(address(this));
        TransferHelpers._safeTransferERC20(token, to, balance);
    }
}
