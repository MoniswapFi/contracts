pragma solidity ^0.8.0;

interface IDolomiteTrader {
    enum BalanceCheckFlag {
        Both,
        From,
        To,
        None
    }

    struct AccountInfo {
        address owner;
        uint256 number;
    }

    enum TraderType {
        ExternalLiquidity,
        InternalLiquidiy,
        IsolationModeUnwrapper,
        IsolationModeWrapper
    }

    struct TraderParam {
        TraderType traderType;
        uint256 makerAccountIndex;
        address trader;
        bytes tradeData;
    }

    enum EventEmissionType {
        None,
        BorrowPosition,
        MarginPosition
    }

    struct TransferAmount {
        uint256 marketId;
        uint256 amountWei;
    }

    struct TransferCollateralParam {
        uint256 fromAccountNumber;
        uint256 toAccountNumber;
        TransferAmount[] transferAmounts;
    }

    struct UserConfig {
        uint256 deadline;
        BalanceCheckFlag balanceCheckFlag;
        EventEmissionType eventType;
    }

    struct ExpiryParam {
        uint256 marketId;
        uint32 expiryTimeDelta;
    }

    struct SwapExactInputForOutputParams {
        uint256 accountNumber;
        uint256[] marketIdsPath;
        uint256 inputAmountWei;
        uint256 minOutputAmountWei;
        TraderParam[] tradersPath;
        AccountInfo[] makerAccounts;
        UserConfig userConfig;
    }

    function swapExactInputForOutput(uint256 _isolationModeMarketId, SwapExactInputForOutputParams calldata _params)
        external;
}
