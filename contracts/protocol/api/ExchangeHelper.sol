pragma solidity ^0.8.0;

import "../interfaces/factories/IPoolFactory.sol";
import "../rewards/Reward.sol";
import "../Pool.sol";
import "../../oracle/Oracle.sol";
import "../interfaces/ITradeHelper.sol";
import "../Voter.sol";
import "../libraries/ProtocolTimeLibrary.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ExchangeHelper is Ownable {
    IPoolFactory public poolFactory;
    ITradeHelper public tradeHelper;
    Oracle public priceOracle;
    address public wETH;
    Voter public voter;

    constructor(
        address _tradeHelper,
        address _voter,
        address _wETH
    ) Ownable() {
        tradeHelper = ITradeHelper(_tradeHelper);
        poolFactory = IPoolFactory(tradeHelper.factory());
        wETH = _wETH;
        voter = Voter(_voter);
    }

    function getTVLInUSDForPool(Pool pool)
        public
        view
        returns (
            uint256 token0VL,
            uint256 token1VL,
            uint256 totalVL
        )
    {
        (uint256 token0USD, ) = priceOracle.getAverageValueInUSD(pool.token0(), pool.reserve0());
        (uint256 token1USD, ) = priceOracle.getAverageValueInUSD(pool.token1(), pool.reserve1());
        token0VL = token0USD;
        token1VL = token1USD;
        totalVL = token0VL + token1VL;
    }

    function getTVLInUSDForAllPools()
        external
        view
        returns (
            uint256 totalTVL,
            uint256[] memory tvls,
            Pool[] memory pools
        )
    {
        uint256 poolsLength = poolFactory.allPoolsLength();
        pools = new Pool[](poolsLength);
        tvls = new uint256[](poolsLength);
        for (uint256 i; i < poolsLength; i++) {
            Pool pool = Pool(poolFactory.allPools(i));
            (, , uint256 poolTVL) = getTVLInUSDForPool(pool);
            totalTVL += poolTVL;
            pools[i] = pool;
            tvls[i] = poolTVL;
        }
    }

    /**
     *
     * @param pool Address of pool
     * @param from Start timestamp
     * @param to End timestamp
     * @return token0Volume
     * @return token1Volume
     */
    function getVolumeLockedPerTimeForPool(
        Pool pool,
        uint256 from,
        uint256 to
    )
        public
        view
        returns (
            uint256 token0Volume,
            uint256 token1Volume,
            uint256 token0VolumeUSD,
            uint256 token1VolumeUSD,
            uint256 totalVolumeUSD
        )
    {
        uint256 observationsLength = pool.observationLength();
        for (uint256 i = 1; i < observationsLength; i++) {
            (uint256 timestampCurrent, uint256 reserve0CumulativeCurrent, uint256 reserve1CumulativeCurrent) = pool
                .observations(i);
            (uint256 timestampPrevious, uint256 reserve0CumulativePrevious, uint256 reserve1CumulativePrevious) = pool
                .observations(i - 1);
            if (timestampPrevious >= from && timestampCurrent >= from && timestampCurrent <= to) {
                uint256 timeElapsed = timestampCurrent - timestampPrevious;
                uint256 _reserve0 = (reserve0CumulativeCurrent - reserve0CumulativePrevious) / timeElapsed;
                uint256 _reserve1 = (reserve1CumulativeCurrent - reserve1CumulativePrevious) / timeElapsed;

                token0Volume += _reserve0;
                token1Volume += _reserve1;
            }
        }

        (token0VolumeUSD, ) = priceOracle.getAverageValueInUSD(pool.token0(), token0Volume);
        (token1VolumeUSD, ) = priceOracle.getAverageValueInUSD(pool.token1(), token1Volume);
        totalVolumeUSD = token0VolumeUSD + token1VolumeUSD;
    }

    function getTotalVolumeLockedPerTime(uint256 from, uint256 to)
        external
        view
        returns (
            uint256 tvlPerTime,
            uint256[] memory volumes,
            Pool[] memory pools
        )
    {
        uint256 poolsLength = poolFactory.allPoolsLength();
        pools = new Pool[](poolsLength);
        volumes = new uint256[](poolsLength);
        for (uint256 i; i < poolsLength; i++) {
            Pool pool = Pool(poolFactory.allPools(i));
            (, , , , uint256 poolTVLPerTime) = getVolumeLockedPerTimeForPool(pool, from, to);
            tvlPerTime += poolTVLPerTime;
            pools[i] = pool;
            volumes[i] = poolTVLPerTime;
        }
    }

    function calculatePriceImpact(
        address tokenA,
        address tokenB,
        uint256 amountIn,
        bool multiHops
    ) external view returns (uint256) {
        uint256 amountInETH;
        if (multiHops) {
            (amountInETH, ) = tradeHelper.getAmountOut(amountIn, tokenA, wETH);
        }
        (uint256 amountOut, bool stable) = amountInETH > 0
            ? tradeHelper.getAmountOut(amountInETH, wETH, tokenB)
            : tradeHelper.getAmountOut(amountIn, tokenA, tokenB);
        address pool = amountInETH > 0
            ? tradeHelper.poolFor(wETH, tokenB, stable)
            : tradeHelper.poolFor(tokenA, tokenB, stable);
        //Get reserve
        if (pool != address(0)) {
            Pool p = Pool(pool);
            uint256 reserve = p.token0() == tokenB ? p.reserve0() : p.reserve1();
            uint256 projectedReserve = reserve - amountOut;
            return (amountOut * 10**18) / projectedReserve;
        }
        return 0;
    }

    function getFeesInUSDForPool(Pool pool) public view returns (uint256 totalValue) {
        address gauge = voter.gauges(address(pool));

        totalValue = 0;

        if (gauge != address(0)) {
            Reward fee = Reward(voter.gaugeToFees(gauge));
            uint256 rewardTokensLength = fee.rewardsListLength();
            for (uint256 i; i < rewardTokensLength; i++) {
                address rewardToken = fee.rewards(i);
                uint256 reward = fee.tokenRewardsPerEpoch(rewardToken, ProtocolTimeLibrary.epochStart(block.timestamp));
                (uint256 rewardInUsd, ) = priceOracle.getAverageValueInUSD(rewardToken, reward);
                totalValue += rewardInUsd;
            }
        }
    }

    function getFeesInUSDForAllPools()
        external
        view
        returns (
            uint256 totalValue,
            uint256[] memory fees,
            Pool[] memory pools
        )
    {
        uint256 poolsLength = poolFactory.allPoolsLength();
        pools = new Pool[](poolsLength);
        fees = new uint256[](poolsLength);
        for (uint256 i; i < poolsLength; i++) {
            Pool pool = Pool(poolFactory.allPools(i));
            uint256 poolFeeUSD = getFeesInUSDForPool(pool);
            totalValue += poolFeeUSD;
            pools[i] = pool;
            fees[i] += poolFeeUSD;
        }
    }

    function getBribesInUSDForPool(Pool pool) public view returns (uint256 totalValue) {
        address gauge = voter.gauges(address(pool));

        totalValue = 0;

        if (gauge != address(0)) {
            Reward bribe = Reward(voter.gaugeToBribe(gauge));
            uint256 rewardTokensLength = bribe.rewardsListLength();
            for (uint256 i; i < rewardTokensLength; i++) {
                address rewardToken = bribe.rewards(i);
                uint256 reward = bribe.tokenRewardsPerEpoch(
                    rewardToken,
                    ProtocolTimeLibrary.epochStart(block.timestamp)
                );
                (uint256 rewardInUsd, ) = priceOracle.getAverageValueInUSD(rewardToken, reward);
                totalValue += rewardInUsd;
            }
        }
    }

    function getBribesInUSDForAllPools()
        external
        view
        returns (
            uint256 totalValue,
            uint256[] memory bribes,
            Pool[] memory pools
        )
    {
        uint256 poolsLength = poolFactory.allPoolsLength();
        pools = new Pool[](poolsLength);
        bribes = new uint256[](poolsLength);
        for (uint256 i; i < poolsLength; i++) {
            Pool pool = Pool(poolFactory.allPools(i));
            uint256 poolBribeUSD = getBribesInUSDForPool(pool);
            totalValue += poolBribeUSD;
            bribes[i] = poolBribeUSD;
            pools[i] = pool;
        }
    }

    function setPriceOracle(address _priceOracle) external onlyOwner {
        priceOracle = Oracle(_priceOracle);
    }
}
