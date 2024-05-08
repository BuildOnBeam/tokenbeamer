// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

import {TokenBeamer} from "./../contracts/TokenBeamer.sol";

contract InternalFunctionHarness is TokenBeamer {
    function processTransfer(
        address from,
        address payable to,
        address token,
        uint16 type_,
        uint id,
        uint value
    ) external {
        _processTransfer(from, to, token, type_, id, value);
    }

    function getApproval(
        address owner,
        address operator,
        address token,
        uint16 type_,
        uint value
    ) external view returns (bool approved) {
        approved = _getApproval(owner, operator, token, type_, value);
    }
}