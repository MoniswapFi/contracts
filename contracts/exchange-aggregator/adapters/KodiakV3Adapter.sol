pragma solidity ^0.8.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IUniswapV3Factory} from "../interfaces/IUniswapV3Factory.sol";
import {IUniswapV3PoolImmutables} from "../interfaces/IUniswapV3PoolImmutables.sol";
import {IUniswapV3PoolActions} from "../interfaces/IUniswapV3PoolActions.sol";
import {Adapter} from "../Adapter.sol";
import {TransferHelpers} from "../../helpers/TransferHelper.sol";
import {SafeCast} from "../lib/uniswapv3/SafeCast.sol";

contract KodiakV3Adapter is Adapter {
    using SafeCast for uint256;
    using Address for address;
    address public immutable factory;
    uint24[] public ALLOWED_FEES;

    uint160 internal constant MIN_SQRT_RATIO = 4295128739;

    error UnsupportedPool();

    constructor(
        address _factory,
        uint256 _swapGasEstimate,
        uint24[] memory _fees
    ) Adapter("Kodiak Finance V3", _swapGasEstimate) {
        factory = _factory;
        ALLOWED_FEES = _fees;
    }

    function _calculateAmountOut(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn
    ) private view returns (uint256 amountOut) {
        bool zeroForOne = tokenIn < tokenOut;
        bytes4 swapSelector = bytes4(keccak256(bytes("swap(address,bool,int256,uint126,bytes)")));
        address pair = IUniswapV3Factory(factory).getPool(tokenIn, tokenOut, fee);
        bool shouldSimulate = true;
        bytes memory externalData = abi.encodePacked(shouldSimulate, block.timestamp, tokenIn, tokenOut, fee, amountIn);
        bytes memory packed = abi.encodeWithSelector(
            swapSelector,
            address(this),
            zeroForOne,
            amountIn.toInt256(),
            MIN_SQRT_RATIO + 1,
            externalData
        );
        (, bytes memory returnData) = pair.staticcall(packed);

        (amountOut, , ) = abi.decode(returnData, (uint256, uint256, address));
    }

    function _query(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view override returns (uint256 amountOut) {
        IUniswapV3Factory fctory = IUniswapV3Factory(factory);

        for (uint256 i = 0; i < ALLOWED_FEES.length; i++) {
            address pair = fctory.getPool(tokenIn, tokenOut, ALLOWED_FEES[i]);

            if (pair != address(0)) {
                uint256 _amountOut = _calculateAmountOut(tokenIn, tokenOut, ALLOWED_FEES[i], amountIn);

                if (_amountOut > amountOut) {
                    amountOut = _amountOut;
                }
            }
        }
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        address to,
        uint256 amountIn,
        uint256 amountOut
    ) internal override {
        address pair;
        IUniswapV3Factory fctory = IUniswapV3Factory(factory);
        bool zeroForOne = tokenIn < tokenOut;

        for (uint256 i = 0; i < ALLOWED_FEES.length; i++) {
            address _pair = fctory.getPool(tokenIn, tokenOut, ALLOWED_FEES[i]);

            if (_pair != address(0)) {
                uint256 _amountOut = _calculateAmountOut(tokenIn, tokenOut, ALLOWED_FEES[i], amountIn);

                if (_amountOut > amountOut) {
                    amountOut = _amountOut;
                    pair = _pair;
                }
            }
        }

        if (pair != address(0)) {
            IUniswapV3PoolActions(pair).swap(to, zeroForOne, amountIn.toInt256(), MIN_SQRT_RATIO + 1, new bytes(0));
        }
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external {
        address sender = msg.sender;
        uint24 fee = IUniswapV3PoolImmutables(sender).fee();
        bool supportedFee;

        for (uint256 i = 0; i < ALLOWED_FEES.length; i++) {
            if (fee == ALLOWED_FEES[i]) {
                supportedFee = true;
                break;
            }
        }

        if (!supportedFee) revert UnsupportedPool();

        (bool shouldSimulate, , , , , ) = abi.decode(_data, (bool, uint256, address, address, uint24, uint256));

        if (shouldSimulate) {
            bytes memory reason = abi.encodePacked(
                uint256(amount1Delta),
                block.timestamp,
                IUniswapV3PoolImmutables(sender).token1()
            );
            assembly {
                mstore(0x00, reason)
                revert(0x00, 0x96)
            }
        }

        if (amount0Delta > 0) {
            IERC20(IUniswapV3PoolImmutables(sender).token0()).transfer(sender, uint256(amount0Delta));
        } else {
            IERC20(IUniswapV3PoolImmutables(sender).token1()).transfer(sender, uint256(amount1Delta));
        }
    }
}
