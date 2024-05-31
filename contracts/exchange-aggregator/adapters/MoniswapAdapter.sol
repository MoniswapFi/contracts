pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../protocol/interfaces/IPool.sol";
import "../../protocol/interfaces/factories/IPoolFactory.sol";
import "../Adapter.sol";
import "../../helpers/TransferHelper.sol";

contract MoniswapAdapter is Adapter {
    using SafeMath for uint256;
    address public immutable factory;

    constructor(address _factory, uint256 _swapGasEstimate) Adapter("Moniswap", _swapGasEstimate) {
        factory = _factory;
    }

    function _query(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view override returns (uint256) {
        if (tokenIn == tokenOut || amountIn == 0) return 0;

        // Try stable first
        address pair = IPoolFactory(factory).getPool(tokenIn, tokenOut, true);

        if (pair == address(0)) pair = IPoolFactory(factory).getPool(tokenIn, tokenOut, false); // Try volatile

        if (pair == address(0)) return 0;

        return IPool(pair).getAmountOut(amountIn, tokenIn);
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        address to,
        uint256 amountIn,
        uint256 amountOut
    ) internal override {
        // Try stable first
        address pair = IPoolFactory(factory).getPool(tokenIn, tokenOut, true);

        if (pair == address(0)) pair = IPoolFactory(factory).getPool(tokenIn, tokenOut, false); // Try volatile

        (uint256 amount0Out, uint256 amount1Out) = tokenIn < tokenOut
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));
        TransferHelpers._safeTransferERC20(tokenIn, pair, amountIn);
        IPool(pair).swap(amount0Out, amount1Out, to, new bytes(0));
    }
}
