// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TokenBeamer} from "../contracts/TokenBeamer.sol";
import {Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";

contract TokenBeamerTest is Test {
    string mnemonic = "test test test test test test test test test test test junk";
    address deployer;
    
    TokenBeamer public tokenBeamer;
    address implementation;
    address proxy;

    function setUp() public {
        uint256 privateKey = vm.deriveKey(mnemonic, 0);
        deployer = vm.addr(privateKey);
        vm.deal(deployer, 100 ether);
        vm.startPrank(deployer);

        // Deploy the upgradeable contract
        proxy = Upgrades.deployTransparentProxy(
            "TokenBeamer.sol",
            msg.sender,
            abi.encodeCall(TokenBeamer.initialize, ())
        );

        // Get the implementation address
        implementation = Upgrades.getImplementationAddress(
            proxy
        );

        tokenBeamer = TokenBeamer(payable(proxy));

        console.log(proxy, implementation);
    }

    function test_DisableUpgrades() public {
        assertEq(tokenBeamer.upgradesDisabled(), false);

        tokenBeamer.disableUpgrades();

        assertEq(tokenBeamer.upgradesDisabled(), true);
    }

    function test_Receive_RevertWhen_EthSent() public {
        vm.expectRevert();
        address(tokenBeamer).call{value: 1 ether}("");
    }

    function testFuzz_setTipRecipient(address payable newTipRecipient) public {
        vm.assume(newTipRecipient != address(0));
        tokenBeamer.setTipRecipient(newTipRecipient);
        address storageTipRecipient = abi.decode(abi.encode(vm.load(proxy, 0x0)), (address));
        assertEq(storageTipRecipient, newTipRecipient);
    }

    function test_setTipRecipient_RevertWhen_BadInput(address payable newTipRecipient) public {
        vm.assume(newTipRecipient != address(0));
        tokenBeamer.setTipRecipient(newTipRecipient);

        vm.expectRevert(TokenBeamer.BadInput.selector);
        tokenBeamer.setTipRecipient(newTipRecipient);

        vm.expectRevert(TokenBeamer.BadInput.selector);
        tokenBeamer.setTipRecipient(payable(address(0)));
    }
}
