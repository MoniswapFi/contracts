pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Sale} from "./Sale.sol";

contract PrivateSale is Sale {
    using SafeERC20 for IERC20;

    error NotWhitelisted();
    error AlreadyWhitelisted();

    mapping(address => bool) public whitelisted;

    constructor() Sale() {}

    function whitelist(address[] memory accounts) external onlyOwner {
        for (uint256 i; i < accounts.length; i++) {
            _whitelist(accounts[i]);
        }
    }

    function removeFromWhitelist(address[] memory accounts) external onlyOwner {
        for (uint256 i; i < accounts.length; i++) {
            _removeFromWhitelist(accounts[i]);
        }
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

    function _beforeContribute(address contributor, uint256 contributed) internal virtual override {
        super._beforeContribute(contributor, contributed);
        if (!whitelisted[contributor]) revert NotWhitelisted();
    }

    function _whitelist(address account) internal {
        if (whitelisted[account]) revert AlreadyWhitelisted();
        whitelisted[account] = true;
    }

    function _removeFromWhitelist(address account) internal {
        if (!whitelisted[account]) revert NotWhitelisted();
        whitelisted[account] = false;
    }
}
