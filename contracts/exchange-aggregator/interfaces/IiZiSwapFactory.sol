// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IiZiSwapFactory {
    function pool(
        address tokenX,
        address tokenY,
        uint24 fee
    ) external view returns (address);
}
