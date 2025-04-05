pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Sale} from "./Sale.sol";

contract RegularSale is Sale {
    using SafeERC20 for IERC20;

    constructor() Sale() {}

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
