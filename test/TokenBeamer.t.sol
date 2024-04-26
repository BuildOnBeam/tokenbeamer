// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {TokenBeamer} from "../contracts/TokenBeamer.sol";
import {Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {MockERC20} from "./MockERC20.sol";
import {MockERC721} from "./MockERC721.sol";
import {MockERC1155} from "./MockERC1155.sol";

contract TokenBeamerTest is Test {
    string mnemonic = "test test test test test test test test test test test junk";
    address deployer;
    address tokenOwner;
    address operator;
    
    TokenBeamer public tokenBeamer;
    address implementation;
    address proxy;

    MockERC20 mockERC20;
    MockERC721 mockERC721;
    MockERC1155 mockERC1155;

    function setUp() public {
        uint256 deployerPK = vm.deriveKey(mnemonic, 0);
        deployer = vm.addr(deployerPK);
        vm.deal(deployer, 100 ether);

        uint256 tokenOwnerPK = vm.deriveKey(mnemonic, 1);
        tokenOwner = vm.addr(tokenOwnerPK);
        vm.deal(tokenOwner, 100 ether);

        uint256 operatorPK = vm.deriveKey(mnemonic, 2);
        operator = vm.addr(operatorPK);
        vm.deal(operator, 100 ether);

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

        setUpMocks();
    }

    function setUpMocks() public {
        mockERC20 = new MockERC20();
        mockERC721 = new MockERC721();
        mockERC1155 = new MockERC1155();

        mockERC20.mint(tokenOwner, 100 ether);
        assertEq(mockERC20.balanceOf(tokenOwner), 100 ether);
        mockERC721.mint(tokenOwner, 1);
        assertEq(mockERC721.ownerOf(1), tokenOwner);
        mockERC1155.mint(tokenOwner, 1, 100 ether);
        assertEq(mockERC1155.balanceOf(tokenOwner, 1), 100 ether);
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
