// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IMinter.sol";
import "../interfaces/factories/IPoolFactory.sol";
import "../interfaces/IVoter.sol";
import "../interfaces/IVotingEscrow.sol";
import "../gauges/Gauge.sol";
import "../Pool.sol";
import "../rewards/Reward.sol";
import "../libraries/ProtocolTimeLibrary.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PoolHelper is Ownable {
    error InvalidPool(address);

    struct PoolInformation {
        // pool info
        address pool_address; // pool contract address
        string symbol; // pool symbol
        string name; // pool name
        uint256 decimals; // pool decimals
        bool stable; // pool pool type (stable = false, means it's a variable type of pool)
        uint256 total_supply; // pool tokens supply
        // token pool info
        address token0; // pool 1st token address
        string token0_symbol; // pool 1st token symbol
        uint256 token0_decimals; // pool 1st token decimals
        uint256 reserve0; // pool 1st token reserves (nr. of tokens in the contract)
        uint256 claimable0; // claimable 1st token from fees (for unstaked positions)
        address token1; // pool 2nd token address
        string token1_symbol; // pool 2nd token symbol
        uint256 token1_decimals; // pool 2nd token decimals
        uint256 reserve1; // pool 2nd token reserves (nr. of tokens in the contract)
        uint256 claimable1; // claimable 2nd token from fees (for unstaked positions)
        // pools gauge
        address gauge; // pool gauge address
        uint256 gauge_total_supply; // pool staked tokens (less/eq than/to pool total supply)
        address fees; // pool fees contract address
        address bribe; // pool bribes contract address
        uint256 emissions; // pool emissions (per second)
        address emissions_token; // pool emissions token address
        uint256 emissions_token_decimals; // pool emissions token decimals
        // User deposit
        uint256 account_lp_balance; // account LP tokens balance
        uint256 account_token0_balance; // account 1st token balance
        uint256 account_token1_balance; // account 2nd token balance
        uint256 account_gauge_balance; // account pool staked in gauge balance
        uint256 account_gauge_earned; // account earned emissions for this pool
    }

    struct TokenBribe {
        address token;
        uint8 decimals;
        uint256 amount;
        string symbol;
    }

    struct PoolBribeEpoch {
        uint256 epochTimestamp;
        uint256 totalSupply;
        address pool;
        TokenBribe[] bribes;
    }

    IPoolFactory public poolFactory;
    IVoter public voter;

    address public underlyingToken;

    event Voter(address oldVoter, address newVoter);

    constructor(address _voter, address _factory) Ownable() {
        voter = IVoter(_voter);

        poolFactory = IPoolFactory(_factory);
        underlyingToken = IVotingEscrow(voter.ve()).token();
    }

    function getAllPools(address _user) external view returns (PoolInformation[] memory pools) {
        uint256 totalPools = poolFactory.allPoolsLength();
        pools = new PoolInformation[](totalPools);
        address _pool;

        for (uint256 i; i < totalPools; i++) {
            _pool = poolFactory.allPools(i);
            pools[i] = poolAddressToInfo(_pool, _user);
        }
    }

    function getPool(address _pool, address _account) external view returns (PoolInformation memory poolInfo) {
        poolInfo = poolAddressToInfo(_pool, _account);
    }

    function poolAddressToInfo(address _pool, address _account)
        internal
        view
        returns (PoolInformation memory poolInfo)
    {
        if (!IPoolFactory(poolFactory).isPool(_pool)) revert InvalidPool(_pool);

        Pool pool = Pool(_pool);

        address token_0 = pool.token0();
        address token_1 = pool.token1();
        (uint256 r0, uint256 r1, ) = pool.getReserves();

        Gauge _gauge = Gauge(voter.gauges(_pool));
        uint256 accountGaugeLPAmount = 0;
        uint256 earned = 0;
        uint256 gaugeTotalSupply = 0;
        uint256 emissions = 0;

        if (address(_gauge) != address(0)) {
            if (_account != address(0)) {
                accountGaugeLPAmount = _gauge.balanceOf(_account);
                earned = _gauge.earned(_account);
            } else {
                accountGaugeLPAmount = 0;
                earned = 0;
            }
            gaugeTotalSupply = _gauge.totalSupply();
            emissions = _gauge.rewardRate();
        }

        // Pool General Info
        poolInfo.pool_address = _pool;
        poolInfo.symbol = pool.symbol();
        poolInfo.name = pool.name();
        poolInfo.decimals = pool.decimals();
        poolInfo.stable = pool.stable();
        poolInfo.total_supply = pool.totalSupply();

        // Token0 Info
        poolInfo.token0 = token_0;
        poolInfo.token0_decimals = ERC20(token_0).decimals();
        poolInfo.token0_symbol = ERC20(token_0).symbol();
        poolInfo.reserve0 = r0;
        poolInfo.claimable0 = pool.claimable0(_account);

        // Token1 Info
        poolInfo.token1 = token_1;
        poolInfo.token1_decimals = ERC20(token_1).decimals();
        poolInfo.token1_symbol = ERC20(token_1).symbol();
        poolInfo.reserve1 = r1;
        poolInfo.claimable1 = pool.claimable1(_account);

        // Pool's gauge Info
        poolInfo.gauge = address(_gauge);
        poolInfo.gauge_total_supply = gaugeTotalSupply;
        poolInfo.emissions = emissions;
        poolInfo.emissions_token = underlyingToken;
        poolInfo.emissions_token_decimals = ERC20(underlyingToken).decimals();

        // external address
        poolInfo.fees = voter.gaugeToFees(address(_gauge));
        poolInfo.bribe = voter.gaugeToBribe(address(_gauge));

        // Account Info
        poolInfo.account_lp_balance = ERC20(_pool).balanceOf(_account);
        poolInfo.account_token0_balance = ERC20(token_0).balanceOf(_account);
        poolInfo.account_token1_balance = ERC20(token_1).balanceOf(_account);
        poolInfo.account_gauge_balance = accountGaugeLPAmount;
        poolInfo.account_gauge_earned = earned;
    }

    function getPoolBribe(address _pool) external view returns (PoolBribeEpoch[] memory _poolEpoch) {
        address _gauge = voter.gauges(_pool);
        if (_gauge == address(0)) return _poolEpoch;

        Reward bribe = Reward(voter.gaugeToBribe(_gauge));
        uint256 totalSupplyCheckpoints = bribe.supplyNumCheckpoints();
        _poolEpoch = new PoolBribeEpoch[](totalSupplyCheckpoints);

        // check bribe and checkpoints exists
        if (address(0) == address(bribe)) return _poolEpoch;

        // if 0 then no bribe created so far
        if (totalSupplyCheckpoints == 0) {
            return _poolEpoch;
        }

        for (uint256 i; i < totalSupplyCheckpoints; i++) {
            (uint256 _ts, uint256 supply) = bribe.supplyCheckpoints(i);
            _poolEpoch[i].epochTimestamp = ProtocolTimeLibrary.epochStart(_ts);
            _poolEpoch[i].totalSupply = supply;
            _poolEpoch[i].pool = _pool;
            _poolEpoch[i].bribes = getBribe(_poolEpoch[i].epochTimestamp, address(bribe));
        }
    }

    function getBribe(uint256 _ts, address _br) internal view returns (TokenBribe[] memory tb) {
        Reward bribe = Reward(_br);
        uint256 tokenLen = bribe.rewardsListLength();

        tb = new TokenBribe[](tokenLen);

        uint256 k;
        uint256 rewardPerEpoch;
        ERC20 token;
        for (k = 0; k < tokenLen; k++) {
            token = ERC20(bribe.rewards(k));
            rewardPerEpoch = bribe.tokenRewardsPerEpoch(address(token), _ts);
            tb[k].token = address(token);
            tb[k].symbol = token.symbol();
            tb[k].decimals = token.decimals();
            tb[k].amount = rewardPerEpoch;
        }
    }

    function setVoter(address _voter) external onlyOwner {
        require(_voter != address(0), "zeroAddr");
        address _oldVoter = address(voter);
        voter = IVoter(_voter);
        underlyingToken = IVotingEscrow(voter.ve()).token();

        emit Voter(_oldVoter, _voter);
    }

    function left(address _pool, address _token) external view returns (uint256 rewardPerEpoch) {
        address _gauge = voter.gauges(_pool);
        Reward bribe = Reward(voter.gaugeToBribe(_gauge));

        uint256 ts = ProtocolTimeLibrary.epochStart(block.timestamp);
        rewardPerEpoch = bribe.tokenRewardsPerEpoch(_token, ts);
    }
}
