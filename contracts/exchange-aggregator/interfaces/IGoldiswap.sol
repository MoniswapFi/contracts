pragma solidity ^0.8.0;

interface IGoldiswap {
    event Buy(address indexed user, uint256 amount, uint256 fsl, uint256 psl, uint256 supply);
    event Sale(address indexed user, uint256 amount, uint256 fsl, uint256 psl, uint256 supply);
    event Redeem(address indexed user, uint256 amount, uint256 fsl, uint256 psl, uint256 supply);

    error NotGoldilocked();
    error NotMultisig();
    error NotTimelock();
    error NotActive();
    error ExcessiveSlippage();

    function floorPrice() external view returns (uint256);

    function marketPrice() external view returns (uint256);

    function buy(uint256 amount, uint256 maxAmount) external;

    function sell(uint256 amount, uint256 minAmount) external;

    function redeem(uint256 amount) external;

    function injectLiquidity(uint256 liquidity) external;

    function fsl() external view returns (uint256);

    function psl() external view returns (uint256);

    function borrowTransfer(
        address to,
        uint256 amount,
        uint256 fee
    ) external;

    function porridgeMint(
        address to,
        uint256 amount,
        uint256 cost
    ) external;

    function initializeProtocol(uint256 amount) external;
}
