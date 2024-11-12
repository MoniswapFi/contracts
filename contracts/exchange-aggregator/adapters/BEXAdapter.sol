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

        (address base, address quote) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        uint8 decimalsIn = ERC20(tokenIn).decimals();
        uint8 decimalsOut = ERC20(tokenOut).decimals();
        uint128 price = ICrocQuery(oracle).queryPrice(base, quote, 36000);
        uint256 amountOut;

        if (price != 0) {
            uint128 priceSQ = (price * 10**18) >> 64;
            uint256 _mulPriceSQ = uint256(priceSQ**2);
            amountOut = _mulPriceSQ == 0
                ? 0
                : (
                    base == tokenIn
                        ? ((amountIn * 10**decimalsOut) / (_mulPriceSQ / 10**18)) / 10**decimalsIn
                        : ((_mulPriceSQ / 10**18) * 10**decimalsOut * amountIn) / 10**decimalsIn
                );
        }

        return amountOut;
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        address to,
        uint256 amountIn,
        uint256 amountOut
    ) internal override {
        ERC20(tokenIn).approve(factory, amountIn);
        ICrocMultiSwap.SwapStep[] memory steps = new ICrocMultiSwap.SwapStep[](1);
        steps[0] = ICrocMultiSwap.SwapStep(36000, tokenIn, tokenOut, true);
        ICrocMultiSwap(factory).multiSwap(steps, uint128(amountIn), uint128(amountOut));
        TransferHelpers._safeTransferERC20(tokenOut, to, amountOut);
    }
}
