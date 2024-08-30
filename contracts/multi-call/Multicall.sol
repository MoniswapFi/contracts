pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract Multicall is Ownable {
    error NotAllowedContract();
    error NotContract();

    using Address for address;

    mapping(address => bool) private ALLOWED_CONTRACTS;

    modifier onlyAllowedContracts(address _contract) {
        if (!ALLOWED_CONTRACTS[_contract]) {
            revert NotAllowedContract();
        }

        _;
    }

    constructor(address[] memory _allowedContracts) Ownable() {
        for (uint256 i = 0; i < _allowedContracts.length; i++) {
            ALLOWED_CONTRACTS[_allowedContracts[i]] = true;
        }
    }

    function multicall(address _contract, bytes[] calldata _bytes) external onlyAllowedContracts(_contract) {
        if (!_contract.isContract()) {
            revert NotContract();
        }

        require(_bytes.length > 0, "no call bytes");

        for (uint256 i = 0; i < _bytes.length; i++) {
            _contract.functionCall(_bytes[i]);
        }
    }

    function switchAllowContract(address _contract) external onlyOwner {
        if (!_contract.isContract()) {
            revert NotContract();
        }

        ALLOWED_CONTRACTS[_contract] = !ALLOWED_CONTRACTS[_contract];
    }
}
