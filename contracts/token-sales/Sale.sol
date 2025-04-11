pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Sale is Ownable {
    error NotStarted();
    error AlreadyStarted();
    error AlreadyEnded();
    error NotEnded();
    error Blacklisted();
    error SlotLimited(uint256 expected, uint256 available);
    error IsZeroAmount();

    using SafeERC20 for IERC20;

    enum SaleType {
        NORMAL,
        VESTABLE,
        WHITELISTABLE
    }

    uint256 public startTime;
    uint256 public duration;
    uint256 public slotLeft;
    uint256 public slotFilled;
    uint256 public rate; // Rate of sold token => payment token
    uint8 public EXCHANGE_TOKEN_DECIMALS;

    IERC20 public soldToken; // Token to be sold
    IERC20 public exchangeToken; // Token to pay with

    address public receiver; // Receiver of proceeds from this
    address public constant ETHER = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE); // Ether representation

    mapping(address => uint256) public contributions; // User's contributions
    mapping(address => bool) public blacklist; // User blocked
    // mapping(address => bool) public hasClaimed; // User has claimed

    SaleType public saleType;

    bool isInitialized;

    constructor() Ownable() {}

    function initialize(
        address newOwner,
        uint256 _startTime,
        uint256 _duration,
        IERC20 _soldToken,
        IERC20 _exchangeToken,
        address _receiver,
        uint256 _rate,
        SaleType _saleType
    ) external {
        require(!isInitialized, "initialized");
        _transferOwnership(newOwner);
        isInitialized = true;
        startTime = _startTime;
        duration = _duration;
        soldToken = _soldToken;
        exchangeToken = _exchangeToken;
        receiver = _receiver;
        rate = _rate;
        saleType = _saleType;

        if (address(_exchangeToken) == address(0) || address(_exchangeToken) == ETHER) EXCHANGE_TOKEN_DECIMALS = 18;
        else {
            EXCHANGE_TOKEN_DECIMALS = ERC20(address(_exchangeToken)).decimals();
        }
    }

    function _getAllocation(uint256 contribution) internal view returns (uint256 allocation) {
        allocation = (contribution * rate) / 10**EXCHANGE_TOKEN_DECIMALS;
    }

    function _beforeContribute(address contributor, uint256 amountContributed) internal virtual {
        if (block.timestamp < startTime) revert NotStarted();
        if (block.timestamp >= startTime + duration) revert AlreadyEnded();
        if (blacklist[contributor]) revert Blacklisted();

        uint256 allocation = _getAllocation(amountContributed); // Allocation that is due to this contributor for this amount contributed
        if (allocation > slotLeft) revert SlotLimited(allocation, slotLeft);
    }

    function contribute(uint256 amount) external payable {
        address _tk = address(exchangeToken);
        address sender = _msgSender();

        if (_tk == ETHER || _tk == address(0)) {
            uint256 value = msg.value;
            if (value == 0) revert IsZeroAmount();
            _beforeContribute(sender, value);
            uint256 allocation = _getAllocation(value);
            contributions[sender] += value;
            slotLeft -= allocation;
            slotFilled += allocation;
        } else {
            if (amount == 0) revert IsZeroAmount();
            _beforeContribute(sender, amount);
            uint256 allocation = _getAllocation(amount);
            contributions[sender] += amount;
            slotLeft -= allocation;
            slotFilled += allocation;
            exchangeToken.safeTransferFrom(sender, address(this), amount);
        }
    }

    function notifyReward(uint256 amount) external onlyOwner {
        if (block.timestamp >= startTime + duration) revert AlreadyEnded();
        soldToken.safeTransferFrom(_msgSender(), address(this), amount);
        slotLeft += amount;
    }

    function rescindContribution() external {
        address sender = _msgSender();
        uint256 contribution = contributions[sender];
        require(contribution != 0, "contribution = 0");
        uint256 allocation = _getAllocation(contribution);
        contributions[sender] = 0;
        slotLeft += allocation;
        slotFilled -= allocation;
        address _tk = address(exchangeToken);

        if (_tk == ETHER || _tk == address(0)) {
            (bool success, ) = sender.call{value: contribution}(new bytes(0));
            require(success, "failed to transfer ether");
        } else {
            exchangeToken.safeTransfer(sender, contribution);
        }
    }

    function _claimAllocation(address account) internal virtual returns (uint256, uint256) {}

    function claimAllocation() external {
        address sender = _msgSender();
        (uint256 contribution, uint256 allocation) = _claimAllocation(sender);
        contributions[sender] -= contribution;
        slotLeft -= allocation;
        slotFilled += allocation;
    }

    function reap() external onlyOwner {
        if (block.timestamp < startTime + duration) revert NotEnded();
        address _tk = address(exchangeToken);

        if (_tk == ETHER || _tk == address(0)) {
            uint256 balance = address(this).balance;
            (bool success, ) = receiver.call{value: balance}(new bytes(0));
            require(success, "failed to transfer ether");
        } else {
            exchangeToken.safeTransfer(receiver, exchangeToken.balanceOf(address(this)));
        }

        if (slotLeft > 0) {
            soldToken.safeTransfer(_msgSender(), slotLeft);
        }
    }

    function forceStart() external onlyOwner {
        if (block.timestamp >= startTime) revert AlreadyStarted();
        startTime = block.timestamp;
    }

    function forceEnd() external onlyOwner {
        if (block.timestamp > startTime + duration) revert AlreadyEnded();
        duration = block.timestamp - startTime;
    }

    function extendStart(uint256 _duration, bool fromPresent) external onlyOwner {
        if (block.timestamp > startTime + duration) revert AlreadyEnded();
        if (fromPresent) {
            startTime = block.timestamp + _duration;
        } else {
            startTime = startTime + _duration;
        }
    }

    function extendDuration(uint256 _duration, bool extendBy) external onlyOwner {
        if (block.timestamp > startTime + duration) revert AlreadyEnded();
        if (extendBy) {
            duration = duration + _duration;
        } else {
            duration = _duration;
        }
    }

    function switchBlacklistStatus(address account) external onlyOwner {
        blacklist[account] = !blacklist[account];
    }

    receive() external payable {}
}
