pragma solidity ^0.8.0;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Adapter} from "../Adapter.sol";
import {TransferHelpers} from "../../helpers/TransferHelper.sol";
import {IiZiSwapFactory} from "../interfaces/IiZiSwapFactory.sol";
import {IiZiSwapQuoter} from "../interfaces/IiZiSwapQuoter.sol";
import {IiZiSwapPool} from "../interfaces/IiZiSwapPool.sol";

contract IzISwapAdapter is Adapter {
    address public factory;
    address public quoter;
    uint24[] public iziFees;

    using Address for address;

    constructor(
        address _factory,
        uint24[] memory _iziFees,
        address _quoter,
        uint256 _swapGasEstimate
    ) Adapter("IzISwap", _swapGasEstimate) {
        factory = _factory;
        iziFees = _iziFees;
        quoter = _quoter;
    }

    function addFee(uint24 fee) external onlyMaintainer {
        iziFees.push(fee);
    }

    function _query(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view override returns (uint256 amountOut) {
        if (tokenIn == tokenOut || amountIn == 0) return 0;

        address pair;
        uint24 fee;

        for (uint256 i = 0; i < iziFees.length; i++) {
            address _pair = IiZiSwapFactory(factory).pool(tokenIn, tokenOut, iziFees[i]);

            if (_pair != address(0)) {
                pair = _pair;
                fee = iziFees[i];
                break;
            }
        }

        if (pair == address(0)) return 0;

        (address tokenA, address tokenB) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
        (amountOut, ) = IiZiSwapQuoter(quoter).swapX2Y(tokenA, tokenB, fee, uint128(amountIn), -799999);
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        address to,
        uint256 amountIn,
        uint256 amountOut
    ) internal override {
        address pair = IiZiSwapFactory(factory).pool(tokenIn, tokenOut, 100);
        uint24 fee = 100;

        if (pair == address(0)) {
            for (uint256 i = 0; i < iziFees.length; i++) {
                address _pair = IiZiSwapFactory(factory).pool(tokenIn, tokenOut, iziFees[i]);

                if (_pair != address(0)) {
                    pair = _pair;
                    fee = iziFees[i];
                    break;
                }
            }
        }

        // TransferHelpers._safeTransferERC20(tokenIn, pair, amountIn);
        (, uint256 amountY) = IiZiSwapPool(pair).swapX2Y(
            to,
            uint128(amountIn),
            -799999,
            abi.encodePacked(tokenIn, fee, tokenOut)
        );
        require(amountY >= amountOut);
    }

    function swapX2YCallback(uint256 amountX, uint256 amountY, bytes memory) external {
        address sender = _msgSender();
        bytes4 tokenXBytes = bytes4(keccak256(bytes("tokenX()")));
        bytes4 tokenYBytes = bytes4(keccak256(bytes("tokenY()")));

        bytes memory tokenXData = sender.functionStaticCall(abi.encodeWithSelector(tokenXBytes));
        bytes memory tokenYData = sender.functionStaticCall(abi.encodeWithSelector(tokenYBytes));

        address tokenX = abi.decode(tokenXData, (address));
        address tokenY = abi.decode(tokenYData, (address));

        if (amountX > 0) {
            TransferHelpers._safeTransferERC20(tokenX, sender, amountX);
        } else {
            TransferHelpers._safeTransferERC20(tokenY, sender, amountY);
        }
    }
}
