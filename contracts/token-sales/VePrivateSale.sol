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
        soldToken.safeTransfer(account, allocation);
    }
}
