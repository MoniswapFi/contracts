pragma solidity ^0.8.0;

interface IHoneyQuery {
    function previewMint(address asset, uint256 amount) external view returns (uint256);

    function previewRedeem(address asset, uint256 honeyAmount) external view returns (uint256);
}
