// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IiZiSwapQuoter {
    function swapX2Y(
        address tokenX,
        address tokenY,
        uint24 fee,
        uint128 amount,
        int24 lowPt
    ) external view returns (uint256 amountY, int24 finalPoint);
}
