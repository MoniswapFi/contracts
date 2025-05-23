pragma solidity ^0.8.0;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";
import {Adapter} from "../Adapter.sol";
import {TransferHelpers} from "../../helpers/TransferHelper.sol";

contract MemeSwapAdapter is Adapter {
    using SafeMath for uint256;
    address public immutable factory;
    uint256 public immutable feeCompliment;
    uint256 internal constant FEE_DENOMINATOR = 1e3;

    constructor(
        address _factory,
        uint256 _fee,
        uint256 _swapGasEstimate
    ) Adapter("MemeSwap", _swapGasEstimate) {
        factory = _factory;
        feeCompliment = FEE_DENOMINATOR - _fee;
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal view returns (uint256) {
        uint256 amountInWithFee = amountIn.mul(feeCompliment);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(FEE_DENOMINATOR).add(amountInWithFee);
        return numerator.div(denominator);
    }

    function _query(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view override returns (uint256) {
        if (tokenIn == tokenOut || amountIn == 0) return 0;
        address pair = IUniswapV2Factory(factory).getPair(tokenIn, tokenOut);

        if (pair == address(0)) return 0;

        (uint256 r0, uint256 r1, ) = IUniswapV2Pair(pair).getReserves();
        (uint256 reserveIn, uint256 reserveOut) = tokenIn < tokenOut ? (r0, r1) : (r1, r0);
        return reserveIn > 0 && reserveOut > 0 ? _getAmountOut(amountIn, reserveIn, reserveOut) : 0;
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        address to,
        uint256 amountIn,
        uint256 amountOut
    ) internal override {
        address pair = IUniswapV2Factory(factory).getPair(tokenIn, tokenOut);
        (uint256 amount0Out, uint256 amount1Out) = tokenIn < tokenOut
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));
        TransferHelpers._safeTransferERC20(tokenIn, pair, amountIn);
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, to, new bytes(0));
    }
}
