pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TransferHelpers} from "../helpers/TransferHelper.sol";
import {IAdapter} from "./interfaces/IAdapter.sol";

abstract contract Adapter is IAdapter, AccessControl, Ownable {
    using SafeMath for uint256;

    string public name;
    bytes32 public maintainerRole = keccak256(abi.encodePacked("MAINTAINER_ROLE"));
    uint256 public swapGasEstimate;

    event AdapterSwap(
        address indexed tokenIn,
        address indexed tokenOut,
        address to,
        uint256 amountIn,
        uint256 amountOut
    );
    event UpdatedGasEstimate(address indexed _adapter, uint256 _newEstimate);
    event SetName(string name);

    constructor(string memory _name, uint256 _gasEstimate) Ownable() {
        _grantRole(maintainerRole, _msgSender());
        setSwapGasEstimate(_gasEstimate);
        setName(_name);
    }

    modifier onlyMaintainer() {
        require(hasRole(maintainerRole, _msgSender()), "only maintainer can access");
        _;
    }

    function setName(string memory _name) public onlyMaintainer {
        require(bytes(_name).length != 0, "invalid adapter name");
        name = _name;
        emit SetName(_name);
    }

    function setMaintainer(address maintainer) external onlyOwner {
        require(!hasRole(maintainerRole, maintainer), "already maintainer");
        _grantRole(maintainerRole, maintainer);
    }

    function removeMaintainer(address maintainer) external onlyOwner {
        require(hasRole(maintainerRole, maintainer), "does not have maintainer role");
        _grantRole(maintainerRole, maintainer);
    }

    function setSwapGasEstimate(uint256 _estimate) public onlyMaintainer {
        require(_estimate != 0, "Invalid gas-estimate");
        swapGasEstimate = _estimate;
        emit UpdatedGasEstimate(address(this), _estimate);
    }

    function recoverERC20(
        address token,
        address to,
        uint256 amount
    ) external onlyMaintainer {
        require(amount > 0, "amount must be greater than 0");
        TransferHelpers._safeTransferERC20(token, to, amount);
    }

    function recoverEther(address to, uint256 amount) external onlyMaintainer {
        require(amount > 0, "amount must be greater than 0");
        TransferHelpers._safeTransferEther(to, amount);
    }

    function _query(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view virtual returns (uint256);

    function query(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        amountOut = _query(tokenIn, tokenOut, amountIn);
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        address to,
        uint256 amountIn,
        uint256 amountOut
    ) internal virtual;

    function swap(
        address tokenIn,
        address tokenOut,
        address to,
        uint256 amountIn,
        uint256 amountOut
    ) external {
        uint256 initialBalance = IERC20(tokenOut).balanceOf(to);
        _swap(tokenIn, tokenOut, to, amountIn, amountOut);
        uint256 diff = IERC20(tokenOut).balanceOf(to).sub(initialBalance);
        require(diff >= amountOut, "not enough amount out");
        emit AdapterSwap(tokenIn, tokenOut, to, amountIn, amountOut);
    }

    receive() external payable {}
}
