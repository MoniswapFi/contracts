pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IHoneyFactory} from "../interfaces/IHoneyFactory.sol";
import {Adapter} from "../Adapter.sol";

contract HoneySwapAdapter is Adapter {
    address public immutable factory;
    address public immutable honey;

    uint256 MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    constructor(
        address _factory,
        uint256 _swapGasEstimate,
        address _honey
    ) Adapter("HoneySwap", _swapGasEstimate) {
        factory = _factory;
        honey = _honey;
    }

    function _query(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view override returns (uint256 _amountOut) {
        IHoneyFactory fctory = IHoneyFactory(factory);

        if (fctory.vaults(tokenIn) == address(0) || fctory.vaults(tokenOut) == address(0)) _amountOut = 0;

        if (tokenIn != honey && tokenOut != honey) _amountOut = 0;

        if (tokenIn == honey) {
            _amountOut = fctory.vaults(tokenOut) == address(0) ? 0 : fctory.previewRedeem(tokenOut, amountIn);
        } else if (tokenOut == honey) {
            _amountOut = fctory.vaults(tokenIn) == address(0) ? 0 : fctory.previewMint(tokenIn, amountIn);
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

        uint256 _gotten;

        ERC20(tokenIn).approve(factory, MAX_INT);

        if (tokenIn == honey) {
            _gotten = IHoneyFactory(factory).redeem(tokenOut, amountIn, to);
        } else if (tokenOut == honey) {
            _gotten = IHoneyFactory(factory).mint(tokenIn, amountIn, to);
        }

        require(_gotten >= amountOut);
    }
}
