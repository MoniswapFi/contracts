// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../rewards/Reward.sol";
import "../interfaces/IPool.sol";
import "../interfaces/factories/IPoolFactory.sol";
import "../interfaces/IVotingEscrow.sol";
import "../interfaces/IVoter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/ProtocolTimeLibrary.sol";

contract RewardHelper is Ownable {
    IPoolFactory public poolFactory;
    IVoter public voter;
    address public underlyingToken;

    struct Bribe {
        address[] tokens;
        string[] symbols;
        uint256[] decimals;
        uint256[] amounts;
    }

    struct Rewards {
        Bribe[] bribes;
    }

    constructor(address _voter, address _factory) {
        voter = IVoter(_voter);
        poolFactory = IPoolFactory(_factory);
        underlyingToken = IVotingEscrow(voter.ve()).token();
    }

    /// @notice Get the rewards available the next epoch.
    function getExpectedClaimForNextEpoch(uint256 tokenId, address[] memory pools)
        external
        view
        returns (Rewards[] memory)
    {
        uint256 i;
        uint256 len = pools.length;
        address _gauge;
        address _bribe;

        Bribe[] memory _tempReward = new Bribe[](2);
        Rewards[] memory _rewards = new Rewards[](len);

        //external
        for (i = 0; i < len; i++) {
            _gauge = voter.gauges(pools[i]);

            // get external
            _bribe = voter.gaugeToBribe(_gauge);
            _tempReward[0] = _getEpochRewards(tokenId, _bribe);

            // get internal
            _bribe = voter.gaugeToFees(_gauge);
            _tempReward[1] = _getEpochRewards(tokenId, _bribe);
            _rewards[i].bribes = _tempReward;
        }

        return _rewards;
    }

    function _getEpochRewards(uint256 tokenId, address _bribe) internal view returns (Bribe memory _rewards) {
        uint256 totalTokens = Reward(_bribe).rewardsListLength();
        uint256[] memory _amounts = new uint256[](totalTokens);
        address[] memory _tokens = new address[](totalTokens);
        string[] memory _symbol = new string[](totalTokens);
        uint256[] memory _decimals = new uint256[](totalTokens);
        uint256 ts = ProtocolTimeLibrary.epochStart(block.timestamp);
        uint256 supplyIndex = Reward(_bribe).getPriorSupplyIndex(block.timestamp);
        uint256 balanceIndex = Reward(_bribe).getPriorBalanceIndex(tokenId, block.timestamp);
        (, uint256 _supply) = Reward(_bribe).supplyCheckpoints(supplyIndex);
        (, uint256 _balance) = Reward(_bribe).checkpoints(tokenId, balanceIndex);
        uint256 i = 0;
        address _token;
        uint256 rewardsPerEpoch;

        for (i; i < totalTokens; i++) {
            _token = Reward(_bribe).rewards(i);
            _tokens[i] = _token;
            if (_balance == 0) {
                _amounts[i] = 0;
                _symbol[i] = "";
                _decimals[i] = 0;
            } else {
                _symbol[i] = ERC20(_token).symbol();
                _decimals[i] = ERC20(_token).decimals();
                rewardsPerEpoch = Reward(_bribe).tokenRewardsPerEpoch(_token, ts);
                _amounts[i] = (((rewardsPerEpoch * 1e18) / _supply) * _balance) / 1e18;
            }
        }

        _rewards.tokens = _tokens;
        _rewards.amounts = _amounts;
        _rewards.symbols = _symbol;
        _rewards.decimals = _decimals;
    }

    // read all the bribe available for a pool
    function getPoolBribe(address pool) external view returns (Bribe[] memory) {
        address _gauge;
        address _bribe;

        Bribe[] memory _tempReward = new Bribe[](2);

        // get external
        _gauge = voter.gauges(pool);
        _bribe = voter.gaugeToBribe(_gauge);
        _tempReward[0] = _getNextEpochRewards(_bribe);

        // get internal
        _bribe = voter.gaugeToFees(_gauge);
        _tempReward[1] = _getNextEpochRewards(_bribe);
        return _tempReward;
    }

    function _getNextEpochRewards(address _bribe) internal view returns (Bribe memory _rewards) {
        uint256 totalTokens = Reward(_bribe).rewardsListLength();
        uint256[] memory _amounts = new uint256[](totalTokens);
        address[] memory _tokens = new address[](totalTokens);
        string[] memory _symbol = new string[](totalTokens);
        uint256[] memory _decimals = new uint256[](totalTokens);
        uint256 ts = ProtocolTimeLibrary.epochNext(block.timestamp);
        uint256 i = 0;
        address _token;
        uint256 rewardsPerEpoch;

        for (i; i < totalTokens; i++) {
            _token = Reward(_bribe).rewards(i);
            _tokens[i] = _token;
            _symbol[i] = ERC20(_token).symbol();
            _decimals[i] = ERC20(_token).decimals();
            rewardsPerEpoch = Reward(_bribe).tokenRewardsPerEpoch(_token, ts);
            _amounts[i] = rewardsPerEpoch;
        }

        _rewards.tokens = _tokens;
        _rewards.amounts = _amounts;
        _rewards.symbols = _symbol;
        _rewards.decimals = _decimals;
    }

    function setVoter(address _voter) external onlyOwner {
        voter = IVoter(_voter);
        // update variable depending on voter
        underlyingToken = IVotingEscrow(voter.ve()).token();
    }
}
