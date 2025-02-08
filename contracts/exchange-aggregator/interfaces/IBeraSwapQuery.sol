pragma solidity ^0.8.0;

import "./IBeraSwapVault.sol";

interface IBeraSwapQuery {
    function querySwap(IBeraSwapVault.SingleSwap memory singleSwap, IBeraSwapVault.FundManagement memory funds)
        external
        returns (uint256);
}
