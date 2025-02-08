pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Adapter} from "../Adapter.sol";
import {IDolomiteMargin} from "../interfaces/IDolomiteMargin.sol";
import {IDolomiteTrader} from "../interfaces/IDolomiteTrader.sol";
import {IDolomiteDepositWithdrawalRouter} from "../interfaces/IDolomiteDepositWithdrawalRouter.sol";

contract DolomiteAdapter is Adapter {
    IDolomiteMargin public immutable margin;
    IDolomiteTrader public immutable trader;
    IDolomiteDepositWithdrawalRouter public immutable deposit_withdrawalRouter;

    constructor(
        address _factory,
        address _trader,
        address _router,
        uint256 _swapGasEstimate
    ) Adapter("Dolomite", _swapGasEstimate) {
        margin = IDolomiteMargin(_factory);
        trader = IDolomiteTrader(_trader);
        deposit_withdrawalRouter = IDolomiteDepositWithdrawalRouter(_router);
    }

    function _query(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view override returns (uint256 _amountOut) {
        uint256 tokenInMarketId;
        uint256 tokenOutMarketId;

        try margin.getMarketIdByTokenAddress(tokenIn) returns (uint256 marketId) {
            tokenInMarketId = marketId;
        } catch {
            return 0;
        }

        try margin.getMarketIdByTokenAddress(tokenOut) returns (uint256 marketId) {
            tokenOutMarketId = marketId;
        } catch {
            return 0;
        }

        IDolomiteMargin.Price memory tokenInMarketPrice = margin.getMarketPrice(tokenInMarketId);
        IDolomiteMargin.Price memory tokenOutMarketPrice = margin.getMarketPrice(tokenOutMarketId);

        uint8 tokenInDecimals = ERC20(tokenIn).decimals();
        uint8 tokenOutDecimals = ERC20(tokenOut).decimals();

        uint256 tokenInMarketValue = ((tokenInMarketPrice.value * 1 ether) / 10**(uint256(36) - tokenInDecimals)); // Convert to value x 10^18 => Refer to (https://docs.dolomite.io/developer-documentation/dolomite-margin-getters#getmarketprice) to understand the logic
        uint256 tokenOutMarketValue = ((tokenOutMarketPrice.value * 1 ether) / 10**(uint256(36) - tokenOutDecimals));

        // Calculate how much amountOut would be yielded by 1 tokenIn
        uint256 amountOutPerTokenIn = (tokenInMarketValue * 10**tokenOutDecimals) / tokenOutMarketValue;
        _amountOut = (amountIn * amountOutPerTokenIn) / 10**tokenInDecimals; // Derive amount out
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        address to,
        uint256 amountIn,
        uint256 amountOut
    ) internal override {
        // uint256 tokenInMarketId;
        // uint256 tokenOutMarketId;
        // try margin.getMarketIdByTokenAddress(tokenIn) returns (uint256 marketId) {
        //     tokenInMarketId = marketId;
        // } catch {
        //     return;
        // }
        // try margin.getMarketIdByTokenAddress(tokenOut) returns (uint256 marketId) {
        //     tokenOutMarketId = marketId;
        // } catch {
        //     return;
        // }
        // ERC20(tokenIn).approve(address(deposit_withdrawalRouter), amountIn);
        // deposit_withdrawalRouter.depositWei(0, 0, tokenInMarketId, amountIn, IDolomiteDepositWithdrawalRouter.EventFlag.None);
        // uint256[] memory marketIdsPath = new uint256[2];
        // // Set market IDs path
        // marketIdsPath[0] = tokenInMarketId;
        // marketIdsPath[1] = tokenOutMarketId;
        // IDolomiteTrader.SwapExactInputForOutputParams swapParams = IDolomiteTrader.SwapExactInputForOutputParams({
        //   accountNumber: 0,
        //   marketIdsPath: marketIdsPath,
        //   inputAmountWei: amountIn,
        //   minOutputAmountWei: 0.25 ether,
        //   makerAccountIndex: 0
        // });
        // trader.swapExactInputForOutput(0, swapParams);
    }
}
