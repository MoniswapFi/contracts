pragma solidity ^0.8.0;

interface ICrocMultiSwap {
    struct SwapStep {
        uint256 poolIdx;
        address base;
        address quote;
        bool isBuy;
    }

    function multiSwap(
        SwapStep[] calldata _steps,
        uint128 _amount,
        uint128 _minOut
    ) external payable returns (uint128 out);
}
