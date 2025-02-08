pragma solidity ^0.8.0;

interface IDolomiteDepositWithdrawalRouter {
    enum EventFlag {
        None,
        Borrow
    }

    /**
     * @param _isolationModeMarketId The market ID of the isolation mode token vault
     *                               (0 if not using isolation mode)
     * @param _toAccountNumber       The account number to deposit into
     * @param _marketId              The ID of the market being deposited
     * @param _amountWei             The amount in Wei to deposit. Use type(uint256).max to deposit
     *                               mgs.sender's entire balance
     * @param _eventFlag             Flag indicating if this deposit should emit
     *                               special events (e.g. opening a borrow position)
     */
    function depositWei(
        uint256 _isolationModeMarketId,
        uint256 _toAccountNumber,
        uint256 _marketId,
        uint256 _amountWei,
        EventFlag _eventFlag
    ) external;

    /**
     * @notice Deposits native ETH by wrapping it to WETH first
     * @param _isolationModeMarketId     The market ID of the isolation mode token vault
     *                                   (0 if not using isolation mode)
     * @param _toAccountNumber           The account number to deposit the wrapped ETH into
     * @param _eventFlag                 Flag indicating if this deposit should emit special
     *                                   events (e.g. opening a borrow position)
     */
    function depositPayable(
        uint256 _isolationModeMarketId,
        uint256 _toAccountNumber,
        EventFlag _eventFlag
    ) external payable;

    /**
     * @param _isolationModeMarketId The market ID of the isolation mode token vault
     *                               (0 if not using isolation mode)
     * @param _toAccountNumber       The account number to deposit into
     * @param _marketId              The ID of the market being deposited
     * @param _amountPar             The amount in Par units to deposit
     * @param _eventFlag             Flag indicating if this deposit should emit special
     *                               events (e.g. opening a borrow position)
     */
    function depositPar(
        uint256 _isolationModeMarketId,
        uint256 _toAccountNumber,
        uint256 _marketId,
        uint256 _amountPar,
        EventFlag _eventFlag
    ) external;
}
