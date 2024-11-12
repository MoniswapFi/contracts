pragma solidity ^0.8.0;

interface IBerpsVault {
    function deposit(uint256 assets, address receiver) external returns (uint256);

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256);
}
