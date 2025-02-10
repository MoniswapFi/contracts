pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHoneyFactory} from "../interfaces/IHoneyFactory.sol";
import {IHoneyQuery} from "../interfaces/IHoneyQuery.sol";
import {Adapter} from "../Adapter.sol";
import "../../helpers/TransferHelper.sol";

contract HoneySwapAdapter is Adapter {
    IHoneyFactory public immutable factory;
    address public immutable honey;
    IHoneyQuery public immutable oracle;

    uint256 MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    constructor(
        address _factory,
        address query_,
        uint256 _swapGasEstimate,
        address _honey
    ) Adapter("HoneySwap", _swapGasEstimate) {
        factory = IHoneyFactory(_factory);
        oracle = IHoneyQuery(query_);
        honey = _honey;
    }

    function _query(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view override returns (uint256 _amountOut) {
        if (factory.vaults(tokenIn) == address(0) || factory.vaults(tokenOut) == address(0)) return 0;
        if (tokenIn != honey && tokenOut != honey) return 0;
        if (amountIn == 0) return 0;

        if (tokenIn == honey) {
            _amountOut = factory.vaults(tokenOut) == address(0) ? 0 : oracle.previewRedeem(tokenOut, amountIn);
        } else if (tokenOut == honey) {
            _amountOut = factory.vaults(tokenIn) == address(0) ? 0 : oracle.previewMint(tokenIn, amountIn);
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

        ERC20(tokenIn).approve(address(factory), MAX_INT);

        if (tokenIn == honey) {
            factory.redeem(tokenOut, amountIn, address(this));
            uint256 assetBalance = IERC20(tokenOut).balanceOf(address(this));

            if (assetBalance > amountOut) {
                TransferHelpers._safeTransferERC20(tokenOut, to, assetBalance);
            } else {
                TransferHelpers._safeTransferERC20(tokenOut, to, amountOut);
            }
        } else if (tokenOut == honey) {
            factory.mint(tokenIn, amountIn, address(this));
            uint256 honeyBalance = IERC20(tokenOut).balanceOf(address(this));

            if (honeyBalance > amountOut) {
                TransferHelpers._safeTransferERC20(tokenOut, to, honeyBalance);
            } else {
                TransferHelpers._safeTransferERC20(tokenOut, to, amountOut);
            }
        }
    }
}
