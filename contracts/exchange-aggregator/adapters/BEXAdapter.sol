pragma solidity ^0.8.0;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ICrocMultiSwap} from "../interfaces/ICrocMultiswap.sol";
import {ICrocQuery} from "../interfaces/ICrocQuery.sol";
import {Adapter} from "../Adapter.sol";
import {TransferHelpers} from "../../helpers/TransferHelper.sol";

contract BexAdapter is Adapter {
    using SafeMath for uint256;

    address public immutable factory;
    address public immutable oracle;

    constructor(
        address _factory,
        uint256 _swapGasEstimate,
        address _oracle
    ) Adapter("BEX", _swapGasEstimate) {
        factory = _factory;
        oracle = _oracle;
    }

    function _query(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view override returns (uint256) {
        if (tokenIn == tokenOut || amountIn == 0) return 0;

        uint8 decimals = ERC20(tokenOut).decimals();
        uint128 price = ICrocQuery(oracle).queryPrice(tokenIn, tokenOut, 36000);
        uint256 amountOut = uint256((price << 128) >> 128).mul(amountIn).div(10**decimals);

        return amountOut;
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        address to,
        uint256 amountIn,
        uint256 amountOut
    ) internal override {
        ICrocMultiSwap.SwapStep[] memory steps = new ICrocMultiSwap.SwapStep[](1);
        steps[0] = ICrocMultiSwap.SwapStep(36000, tokenIn, tokenOut, true);
        ICrocMultiSwap(factory).multiSwap(steps, uint128(amountIn), uint128(amountOut));
        TransferHelpers._safeTransferERC20(tokenOut, to, amountOut);
    }
}
