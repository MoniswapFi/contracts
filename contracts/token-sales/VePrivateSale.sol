pragma solidity ^0.8.0;

import {PrivateSale} from "./PrivateSale.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVotingEscrow} from "../protocol/interfaces/IVotingEscrow.sol";

/// @title VePrivateSale
/// @author Kingsley Victor
/// @notice Special private sale
contract VePrivateSale is PrivateSale {
    error NotSameToken();

    using SafeERC20 for IERC20;

    IVotingEscrow public votingEscrow;

    constructor() PrivateSale() {}

    function setVe(IVotingEscrow _votingEscrow) external onlyOwner {
        votingEscrow = _votingEscrow;
        if (votingEscrow.token() != address(soldToken)) revert NotSameToken();
        soldToken.safeApprove(address(votingEscrow), type(uint256).max);
    }

    function _claimAllocation(address account)
        internal
        virtual
        override
        returns (uint256 contribution, uint256 allocation)
    {
        if (block.timestamp < startTime + duration) revert NotEnded();
        contribution = contributions[account];
        require(contribution != 0, "contribution = 0");
        allocation = _getAllocation(contribution);
        // Send 30% out
        uint256 _out0 = (30 * allocation) / 100;
        soldToken.safeTransfer(account, _out0);
        // Calculate 10% and lock
        uint256 _out1 = (10 * allocation) / 100;
        uint256 tokenId;
        // Lock for 1 month
        tokenId = votingEscrow.createLock(_out1, 4 weeks);
        votingEscrow.lockPermanent(tokenId);
        votingEscrow.safeTransferFrom(address(this), account, tokenId);
        // Lock for 2 months
        tokenId = votingEscrow.createLock(_out1, 8 weeks);
        votingEscrow.lockPermanent(tokenId);
        votingEscrow.safeTransferFrom(address(this), account, tokenId);
        // Lock for 3 months
        tokenId = votingEscrow.createLock(_out1, 12 weeks);
        votingEscrow.lockPermanent(tokenId);
        votingEscrow.safeTransferFrom(address(this), account, tokenId);
        // Lock for 4 months
        tokenId = votingEscrow.createLock(_out1, 16 weeks);
        votingEscrow.lockPermanent(tokenId);
        votingEscrow.safeTransferFrom(address(this), account, tokenId);
        // Lock for 5 months
        tokenId = votingEscrow.createLock(_out1, 20 weeks);
        votingEscrow.lockPermanent(tokenId);
        votingEscrow.safeTransferFrom(address(this), account, tokenId);
        // Lock for 6 months
        tokenId = votingEscrow.createLock(_out1, 24 weeks);
        votingEscrow.lockPermanent(tokenId);
        votingEscrow.safeTransferFrom(address(this), account, tokenId);
        // Lock for 7 months
        tokenId = votingEscrow.createLock(_out1, 28 weeks);
        votingEscrow.lockPermanent(tokenId);
        votingEscrow.safeTransferFrom(address(this), account, tokenId);
    }
}
