pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 _totalSupply
    ) ERC20(name_, symbol_) {
        _mint(_msgSender(), _totalSupply);
    }
}
