// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IMoni} from "./interfaces/IMoni.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAirdropDistributor} from "./interfaces/IAirdropDistributor.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

contract AirdropDistributor is IAirdropDistributor, Ownable, Pausable {
    using SafeERC20 for IMoni;
    /// @inheritdoc IAirdropDistributor
    IMoni public immutable moni;
    /// @inheritdoc IAirdropDistributor
    IVotingEscrow public immutable ve;

    mapping(address => uint256) public distributedAmounts;

    constructor(address _ve) {
        ve = IVotingEscrow(_ve);
        moni = IMoni(IVotingEscrow(_ve).token());
        // Pause contract
        _pause();
    }

    /// @inheritdoc IAirdropDistributor
    function distributeTokens(address[] memory _wallets, uint256[] memory _amounts) external override onlyOwner {
        uint256 _len = _wallets.length;
        if (_len != _amounts.length) revert InvalidParams();
        uint256 _sum;
        for (uint256 i = 0; i < _len; i++) {
            _sum += _amounts[i];
        }

        if (_sum > moni.balanceOf(address(this))) revert InsufficientBalance();

        moni.safeApprove(address(ve), _sum);

        address _wallet;
        uint256 _amount;
        // uint256 _tokenId;
        for (uint256 i = 0; i < _len; i++) {
            _wallet = _wallets[i];
            _amount = _amounts[i];
            distributedAmounts[_wallet] = _amount;
            // _tokenId = ve.createLock(_amount, 1 weeks);
            // ve.lockPermanent(_tokenId);
            // ve.safeTransferFrom(address(this), _wallet, _tokenId);
        }
        // moni.safeApprove(address(ve), 0);
    }

    function claimAirdrop() external whenNotPaused {
        address _sender = msg.sender;
        uint256 _allocation = distributedAmounts[_sender];
        if (_allocation == 0) revert NoAllocation();
        // Send 20% out
        uint256 _out = (20 * _allocation) / 100;
        moni.safeTransfer(_sender, _out);
        uint256 _tokenId;
        emit Airdrop(_sender, _out, 0);
        // Lock 30% for 1 year in veMoni
        uint256 _lock1Year = (30 * _allocation) / 100;
        _tokenId = ve.createLock(_lock1Year, 365 days);
        ve.lockPermanent(_tokenId);
        ve.safeTransferFrom(address(this), _sender, _tokenId);
        emit Airdrop(_sender, _lock1Year, _tokenId);

        // Lock 50% for 2 years in veMoni
        uint256 _lock2Years = (50 * _allocation) / 100;
        _tokenId = ve.createLock(_lock2Years, 730 days);
        ve.lockPermanent(_tokenId);
        ve.safeTransferFrom(address(this), _sender, _tokenId);
        emit Airdrop(_sender, _lock2Years, _tokenId);
    }

    function start() external onlyOwner {
        _unpause();
    }
}
