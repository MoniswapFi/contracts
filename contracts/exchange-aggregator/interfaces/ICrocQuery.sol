pragma solidity ^0.8.0;

interface ICrocQuery {
    function queryPrice(
        address base,
        address quote,
        uint256 poolIdx
    ) external view returns (uint128);

    function queryCurveTick(
        address base,
        address quote,
        uint256 poolIdx
    ) external view returns (int24);

    function queryLiquidity(
        address base,
        address quote,
        uint256 poolIdx
    ) external view returns (uint128);

    function queryAmbientTokens(
        address owner,
        address base,
        address quote,
        uint256 poolIdx
    )
        external
        view
        returns (
            uint128 liq,
            uint128 baseQty,
            uint128 quoteQty
        );
}
