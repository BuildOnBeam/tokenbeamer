// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TokenBeamer} from "../contracts/TokenBeamer.sol";

contract TokenBeamerTest is Test {
    TokenBeamer public tokenBeamer;

    function setUp() public {
        tokenBeamer = new TokenBeamer();
    }

    // function test_Increment() public {
    //     counter.increment();
    //     assertEq(counter.number(), 1);
    // }

    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
