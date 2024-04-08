# Protocol

All contracts for the Protocol, an AMM on EVMs.

## Protocol Overview

### AMM contracts

| Filename              | Description                                                                               |
| --------------------- | ----------------------------------------------------------------------------------------- |
| `Pool.sol`            | AMM constant-product implementation similar to Uniswap V2 liquidity pools                 |
| `Router.sol`          | Handles multi-pool swaps, deposit/withdrawal, similar to Uniswap V2 Router interface      |
| `PoolFees.sol`        | Stores the liquidity pool trading fees, these are kept separate from the reserves         |
| `ProtocolLibrary.sol` | Provides router-related helpers, eg. for price-impact calculations                        |
| `FactoryRegistry.sol` | Registry of factories approved for creation of pools, gauges, bribes and managed rewards. |

### Tokenomy contracts

| Filename                 | Description                                                                                                                                                                |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Moni.sol`               | Protocol ERC20 token                                                                                                                                                       |
| `VotingEscrow.sol`       | Protocol ERC-721 (ve)NFT representing the protocol vote-escrow lock. Beyond standard ve-type functions, there is also the ability to merge, split and create managed nfts. |
| `Minter.sol`             | Protocol token minter. Distributes emissions to `Voter.sol` and rebases to `RewardsDistributor.sol`.                                                                       |
| `RewardsDistributor.sol` | Is used to handle the rebases distribution for (ve)NFTs/lockers.                                                                                                           |
| `VeArtProxy.sol`         | (ve)NFT art proxy contract, exists for upgradability purposes                                                                                                              |
| `AirdropDistributor.sol` | Distributes permanently locked (ve)NFTs to the provided addresses, in the desired amounts.                                                                                 |

### Protocol mechanics contracts

| Filename                  | Description                                                                                                                                                                                                                                                                                                                                         |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Voter.sol`               | Handles votes for the current epoch, gauge and voting reward creation as well as emission distribution to `Gauge.sol` contracts.                                                                                                                                                                                                                    |
| `Gauge.sol`               | Gauges are attached to a Pool and based on the (ve)NFT votes it receives, it distributes proportional emissions in the form of protocol tokens. Deposits to the gauge take the form of LP tokens for the Pool. In exchange for receiving protocol emissions, claims on fees from the pool are relinquished to the gauge. Standard rewards contract. |
| `rewards/`                |                                                                                                                                                                                                                                                                                                                                                     |
| `Reward.sol`              | Base reward contract to be inherited for distribution of rewards to stakers.                                                                                                                                                                                                                                                                        |
| `VotingReward.sol`        | Rewards contracts used by `FeesVotingReward.sol` and `BribeVotingReward.sol` which inherits `Reward.sol`. Rewards are distributed in the following epoch proportionally based on the last checkpoint created by the user, and are earned through "voting" for a pool or gauge.                                                                      |
| `FeesVotingReward.sol`    | Stores LP fees (from the gauge via `PoolFees.sol`) to be distributed for the current voting epoch to it's voters.                                                                                                                                                                                                                                   |
| `BribeVotingReward.sol`   | Stores the users/externally provided rewards for the current voting epoch to it's voters. These are deposited externally every week.                                                                                                                                                                                                                |
| `ManagedReward.sol`       | Staking implementation for managed veNFTs used by `LockedManagedReward.sol` and `FreeManagedReward.sol` which inherits `Reward.sol`. Rewards can be earned passively by veNFTs who delegate their voting power to a "managed" veNFT.                                                                                                                |
| `LockedManagedReward.sol` | Handles "locked" rewards (i.e. Aero rewards / rebases that are compounded) for managed NFTs. Rewards are not distributed and only returned to `VotingEscrow.sol` when the user withdraws from the managed NFT.                                                                                                                                      |
| `FreeManagedReward.sol`   | Handles "free" (i.e. unlocked) rewards for managed NFTs. Any rewards earned by a managed NFT that a manager passes on will be distributed to the users that deposited into the managed NFT.                                                                                                                                                         |

### Governance contracts

| Filename               | Description                                                                                                                                                                    |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ProtocolGovernor.sol` | OpenZeppelin's Governor contracts used in protocol-wide access control to whitelist tokens for trade within the protocol, update minting emissions, and create managed veNFTs. |
| `EpochGovernor.sol`    | A simple epoch-based governance contract used exclusively for adjusting emissions.                                                                                             |
