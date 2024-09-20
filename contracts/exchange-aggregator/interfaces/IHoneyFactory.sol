pragma solidity ^0.8.0;

interface IHoneyFactory {
    function previewMint(address asset, uint256 amount) external view returns (uint256);

    function previewRedeem(address asset, uint256 honeyAmount) external view returns (uint256);

    function mint(
        address asset,
        uint256 amount,
        address receiver
    ) external returns (uint256);

    function redeem(
        address asset,
        uint256 honeyAmount,
        address receiver
    ) external returns (uint256);

    function vaults(address asset) external view returns (address vault);
}
