pragma solidity ^0.8.0;

interface IHoneyFactory {
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
