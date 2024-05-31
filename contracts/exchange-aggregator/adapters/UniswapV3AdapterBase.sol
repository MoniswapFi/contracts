pragma solidity ^0.8.0;

import {UniswapV3likeAdapter} from "./UniswapV3LikeAdapter.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Factory} from "../interfaces/IUniswapV3Factory.sol";
import {IUniswapV3PoolState} from "../interfaces/IUniswapV3PoolState.sol";

contract UniswapV3AdapterBase is UniswapV3likeAdapter {
    using SafeERC20 for IERC20;

    address public immutable FACTORY;
    mapping(uint24 => bool) public isFeeAmountEnabled;
    uint24[] public feeAmounts;

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        uint256 _quoterGasLimit,
        address _quoter,
        address _factory,
        uint24[] memory _defaultFees
    ) UniswapV3likeAdapter(_name, _swapGasEstimate, _quoter, _quoterGasLimit) {
        FACTORY = _factory;
        for (uint256 i = 0; i < _defaultFees.length; i++) {
            addFeeAmount(_defaultFees[i]);
        }
    }

    function enableFeeAmounts(uint24[] calldata _amounts) external onlyMaintainer {
        for (uint256 i; i < _amounts.length; ++i) enableFeeAmount(_amounts[i]);
    }

    function enableFeeAmount(uint24 _fee) internal {
        require(!isFeeAmountEnabled[_fee], "Fee already enabled");
        if (IUniswapV3Factory(FACTORY).feeAmountTickSpacing(_fee) == 0) revert("Factory doesn't support fee");
        addFeeAmount(_fee);
    }

    function addFeeAmount(uint24 _fee) internal {
        isFeeAmountEnabled[_fee] = true;
        feeAmounts.push(_fee);
    }

    function getBestPool(address token0, address token1) internal view override returns (address mostLiquid) {
        uint128 deepestLiquidity;
        for (uint256 i; i < feeAmounts.length; ++i) {
            address pool = IUniswapV3Factory(FACTORY).getPool(token0, token1, feeAmounts[i]);
            if (pool == address(0)) continue;
            uint128 liquidity = IUniswapV3PoolState(pool).liquidity();
            if (liquidity > deepestLiquidity) {
                deepestLiquidity = liquidity;
                mostLiquid = pool;
            }
        }
    }
}
