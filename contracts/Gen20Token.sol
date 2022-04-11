//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Gen20Token is ERC20 {
    constructor(
        uint256 initialSupply, 
        string memory name, 
        string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}