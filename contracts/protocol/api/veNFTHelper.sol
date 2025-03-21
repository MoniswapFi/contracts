// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../rewards/Reward.sol";
import "../interfaces/IPool.sol";
import "../interfaces/factories/IPoolFactory.sol";
import "../Voter.sol";
import "../interfaces/IVotingEscrow.sol";
import "../interfaces/IRewardsDistributor.sol";
import "./PoolHelper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract veNFTHelper is Ownable {
    struct PoolVote {
        address pool;
        uint256 weight;
    }

    struct veNFT {
        uint8 decimals;
        bool voted;
        uint256 id;
        uint128 amount;
        uint256 voting_amount;
        uint256 rebase_amount;
        uint256 lockEnd;
        uint256 vote_ts;
        PoolVote[] votes;
        address account;
        address token;
        string tokenSymbol;
        uint256 tokenDecimals;
    }

    struct veReward {
        uint256 id;
        uint256 amount;
        uint8 decimals;
        address pool;
        address token;
        address fee;
        address bribe;
        string symbol;
    }

    uint256 public constant MAX_RESULTS = 1000;
    uint256 public constant MAX_POOLS = 30;

    Voter public voter;
    address public underlyingToken;

    IVotingEscrow public ve;
    IRewardsDistributor public rewardDisitributor;

    address public poolHelper;
    IPoolFactory public poolFactory;

    struct AllPoolRewards {
        veReward[] rewards;
    }

    constructor(
        address _voter,
        address _rewardDistro,
        address _poolHelper,
        address _poolFactory
    ) Ownable() {
        poolHelper = _poolHelper;
        voter = Voter(_voter);
        rewardDisitributor = IRewardsDistributor(_rewardDistro);

        require(address(rewardDisitributor.ve()) == voter.ve(), "ve!=ve");

        ve = IVotingEscrow(address(rewardDisitributor.ve()));
        underlyingToken = IVotingEscrow(ve).token();
        poolFactory = IPoolFactory(_poolFactory);
    }

    function getAllNFTs() external view returns (veNFT[] memory _veNFT) {
        uint256 _amounts = ve.tokenId();
        _veNFT = new veNFT[](_amounts);
        address _owner;

        if (_amounts < 1) return _veNFT;

        for (uint256 i = 1; i <= _amounts; i++) {
            _owner = ve.ownerOf(i);
            // if id_i has owner read data
            if (_owner != address(0)) {
                _veNFT[i] = _getNFTFromId(i, _owner);
            }
        }
    }

    function getNFTFromId(uint256 id) external view returns (veNFT memory) {
        return _getNFTFromId(id, ve.ownerOf(id));
    }

    function getNFTFromAddress(address _user) external view returns (veNFT[] memory venft) {
        uint256 i = 0;
        uint256 _id;
        uint256 totalNFTs = ve.balanceOf(_user);

        venft = new veNFT[](totalNFTs);

        for (i; i < totalNFTs; i++) {
            _id = ve.ownerToNFTokenIdList(_user, i);
            if (_id != 0) {
                venft[i] = _getNFTFromId(_id, _user);
            }
        }
    }

    function _getNFTFromId(uint256 id, address _owner) internal view returns (veNFT memory venft) {
        if (_owner == address(0)) {
            return venft;
        }

        PoolVote[] memory votes = new PoolVote[](MAX_POOLS);

        IVotingEscrow.LockedBalance memory _lockedBalance;
        _lockedBalance = ve.locked(id);

        uint256 k;
        uint256 _poolWeight;
        address _votedPool;

        for (k = 0; k < MAX_POOLS; k++) {
            _votedPool = voter.poolVote(id, k);
            if (_votedPool == address(0)) {
                break;
            }
            _poolWeight = voter.votes(id, _votedPool);
            votes[k].pool = _votedPool;
            votes[k].weight = _poolWeight;
        }

        venft.id = id;
        venft.account = _owner;
        venft.decimals = ve.decimals();
        venft.amount = uint128(_lockedBalance.amount);
        venft.voting_amount = ve.balanceOfNFT(id);
        venft.rebase_amount = rewardDisitributor.claimable(id);
        venft.lockEnd = _lockedBalance.end;
        venft.vote_ts = voter.lastVoted(id);
        venft.votes = votes;
        venft.token = ve.token();
        venft.tokenSymbol = ERC20(ve.token()).symbol();
        venft.tokenDecimals = ERC20(ve.token()).decimals();
        venft.voted = ve.voted(id);
    }

    // used only for sAMM and vAMM
    function allPoolRewards(uint256 id) external view returns (AllPoolRewards[] memory rewards) {
        uint256 totalPools = poolFactory.allPoolsLength();
        rewards = new AllPoolRewards[](totalPools);

        uint256 i = 0;
        address _pool;
        for (i; i < totalPools; i++) {
            _pool = poolFactory.allPools(i);
            rewards[i].rewards = _poolReward(_pool, id);
        }
    }

    function singlePoolReward(uint256 id, address _pool) external view returns (veReward[] memory _reward) {
        _reward = _poolReward(_pool, id);
    }

    function _poolReward(address _pool, uint256 id) internal view returns (veReward[] memory _reward) {
        if (_pool == address(0)) {
            return _reward;
        }

        PoolHelper.PoolInformation memory _poolInfo = PoolHelper(poolHelper).getPool(_pool, address(0));

        address externalBribe = _poolInfo.bribe;

        uint256 totalBribeTokens = (externalBribe == address(0)) ? 0 : Reward(externalBribe).rewardsListLength();

        uint256 bribeAmount;

        _reward = new veReward[](2 + totalBribeTokens);

        address _gauge = (voter.gauges(_pool));

        if (_gauge == address(0)) {
            return _reward;
        }

        address t0 = _poolInfo.token0;
        address t1 = _poolInfo.token1;
        uint256 _feeToken0 = Reward(_poolInfo.fees).earned(t0, id);
        uint256 _feeToken1 = Reward(_poolInfo.fees).earned(t1, id);

        if (_feeToken0 > 0) {
            _reward[0] = veReward({
                id: id,
                pool: _pool,
                amount: _feeToken0,
                token: t0,
                symbol: ERC20(t0).symbol(),
                decimals: ERC20(t0).decimals(),
                fee: _poolInfo.fees,
                bribe: address(0)
            });
        }

        if (_feeToken1 > 0) {
            _reward[1] = veReward({
                id: id,
                pool: _pool,
                amount: _feeToken1,
                token: t1,
                symbol: ERC20(t1).symbol(),
                decimals: ERC20(t1).decimals(),
                fee: _poolInfo.fees,
                bribe: address(0)
            });
        }

        //externalBribe point to Bribes.sol
        if (externalBribe == address(0)) {
            return _reward;
        }

        uint256 k = 0;
        address _token;

        for (k; k < totalBribeTokens; k++) {
            _token = Reward(externalBribe).rewards(k);
            bribeAmount = Reward(externalBribe).earned(_token, id);

            _reward[2 + k] = veReward({
                id: id,
                pool: _pool,
                amount: bribeAmount,
                token: _token,
                symbol: ERC20(_token).symbol(),
                decimals: ERC20(_token).decimals(),
                fee: address(0),
                bribe: externalBribe
            });
        }

        return _reward;
    }

    function setVoter(address _voter) external onlyOwner {
        voter = Voter(_voter);
    }

    function setRewardDistro(address _rewardDistro) external onlyOwner {
        rewardDisitributor = IRewardsDistributor(_rewardDistro);
        require(address(rewardDisitributor.ve()) == voter.ve(), "ve!=ve");

        ve = IVotingEscrow(rewardDisitributor.ve());
        underlyingToken = IVotingEscrow(ve).token();
    }

    function setPoolHelper(address _poolHelper) external onlyOwner {
        poolHelper = _poolHelper;
    }

    function setPoolFactory(address _poolFactory) external onlyOwner {
        poolFactory = IPoolFactory(_poolFactory);
    }
}
