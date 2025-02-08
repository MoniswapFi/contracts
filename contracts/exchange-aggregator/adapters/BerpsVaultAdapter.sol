pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHoneyFactory} from "../interfaces/IHoneyFactory.sol";
import {IBerpsVault} from "../interfaces/IBerpsVault.sol";
import {Adapter} from "../Adapter.sol";
import {TransferHelpers} from "../../helpers/TransferHelper.sol";

contract BerpsVaultAdapter is Adapter {
    address public immutable vault;
    address public immutable honey;
    address public immutable bHoney;

    uint256 MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    constructor(
        address _vault,
        uint256 _swapGasEstimate,
        address _honey,
        address _bHoney
    ) Adapter("BerpsVault", _swapGasEstimate) {
        vault = _vault;
        honey = _honey;
        bHoney = _bHoney;
    }

    function _query(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view override returns (uint256 _amountOut) {
        if (tokenIn != honey && tokenIn != bHoney) _amountOut = 0;
        if (tokenOut != honey && tokenOut != bHoney) _amountOut = 0;

        if ((tokenIn == honey && tokenOut == bHoney) || (tokenIn == bHoney && tokenOut == honey)) {
            uint8 decimals0 = ERC20(tokenIn).decimals();
            uint8 decimals1 = ERC20(tokenOut).decimals();

            _amountOut = (amountIn * (10**decimals1)) / (10**decimals0);
        }
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        address to,
        uint256 amountIn,
        uint256 amountOut
    ) internal override {
        require(tokenIn == honey || tokenIn == bHoney);
        require(tokenOut == honey || tokenOut == bHoney);

        IBerpsVault _vault = IBerpsVault(vault);
        ERC20(tokenIn).approve(vault, MAX_INT);

        if (tokenIn == honey) {
            _vault.deposit(amountIn, address(this));
        } else {
            _vault.withdraw(amountIn, address(this), address(this));
        }

        uint256 contractBalance = IERC20(tokenOut).balanceOf(address(this));

        if (contractBalance > amountOut) TransferHelpers._safeTransferERC20(tokenOut, to, contractBalance);
        else TransferHelpers._safeTransferERC20(tokenOut, to, amountOut);

        // require(IERC20(tokenOut).balanceOf(address(this)) >= amountOut);
    }
}
