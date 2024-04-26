// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor()
    ERC20("MockERC20", "M20") {}

    function mint(address account, uint amount) external {
        _mint(account, amount);
    }
}