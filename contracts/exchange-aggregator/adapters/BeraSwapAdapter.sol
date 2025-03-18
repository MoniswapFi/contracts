pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/IBeraSwapVault.sol";
import "../interfaces/IBeraSwapQuery.sol";
import "../Adapter.sol";
import "../../helpers/TransferHelper.sol";

contract BeraSwapAdapter is Adapter {
    IBeraSwapVault public immutable vault;
    IBeraSwapQuery public immutable oracle;

    bytes32[] public poolIds;

    constructor(
        address _factory,
        address query_,
        bytes32[] memory _poolIds,
        uint256 _swapGasEstimate
    ) Adapter("BeraSwap", _swapGasEstimate) {
        vault = IBeraSwapVault(_factory);
        oracle = IBeraSwapQuery(query_);
        setPoolIds(_poolIds);
    }

    function setPoolIds(bytes32[] memory _poolIds) public onlyOwner {
        poolIds = _poolIds;
    }

    function _arrayContains(address[] memory addresses, address target) private pure returns (bool) {
        bool val;

        for (uint256 i; i < addresses.length; i++) {
            if (addresses[i] == target) {
                val = true;
                break;
            }
        }

        return val;
    }

    function _getPoolIdForTokens(address token0, address token1) private view returns (bytes32) {
        if (poolIds.length == 0) return bytes32(0);

        bytes32 _val;
        for (uint256 i; i < poolIds.length; i++) {
            (address[] memory tokens, , ) = vault.getPoolTokens(poolIds[i]);
            if (_arrayContains(tokens, token0) && _arrayContains(tokens, token1)) {
                _val = poolIds[i];
                break;
            }
        }

        return _val;
    }

    function _query(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view override returns (uint256) {
        bytes32 poolId = _getPoolIdForTokens(tokenIn, tokenOut);
        if (poolId == bytes32(0)) return 0;
        IBeraSwapVault.SingleSwap memory singleSwap = IBeraSwapVault.SingleSwap(
            poolId,
            IBeraSwapVault.SwapKind.GIVEN_IN,
            tokenIn,
            tokenOut,
            amountIn,
            ""
        );
        IBeraSwapVault.FundManagement memory fundManagement = IBeraSwapVault.FundManagement(
            address(this),
            false,
            payable(address(this)),
            false
        );

        (bool success, bytes memory result) = address(oracle).staticcall(
            abi.encodeWithSelector(oracle.querySwap.selector, singleSwap, fundManagement)
        );
        if (!success) return 0;
        uint256 returnValue = abi.decode(result, (uint256));
        return returnValue;
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        address to,
        uint256 amountIn,
        uint256 amountOut
    ) internal override {
        bytes32 poolId = _getPoolIdForTokens(tokenIn, tokenOut);
        if (poolId != bytes32(0)) {
            ERC20(tokenIn).approve(address(vault), amountIn);
            IBeraSwapVault.SingleSwap memory singleSwap = IBeraSwapVault.SingleSwap(
                poolId,
                IBeraSwapVault.SwapKind.GIVEN_IN,
                tokenIn,
                tokenOut,
                amountIn,
                new bytes(0)
            );
            IBeraSwapVault.FundManagement memory fundManagement = IBeraSwapVault.FundManagement(
                address(this),
                false,
                payable(address(this)),
                false
            );

            uint256 deadline = block.timestamp + 72000; // 20 minutes
            vault.swap(singleSwap, fundManagement, amountOut, deadline);
            uint256 balanceAfter = ERC20(tokenOut).balanceOf(address(this));
            if (balanceAfter > amountOut) {
                TransferHelpers._safeTransferERC20(tokenOut, to, balanceAfter);
            } else {
                TransferHelpers._safeTransferERC20(tokenOut, to, amountOut);
            }
        }
    }
}
