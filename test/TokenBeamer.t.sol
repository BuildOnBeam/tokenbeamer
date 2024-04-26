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
    address receiver;
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

        uint256 receiverPK = vm.deriveKey(mnemonic, 1);
        receiver = vm.addr(receiverPK);
        vm.deal(receiver, 100 ether);

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

        vm.stopPrank();
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
        vm.startPrank(deployer);
        assertEq(tokenBeamer.upgradesDisabled(), false);

        tokenBeamer.disableUpgrades();

        assertEq(tokenBeamer.upgradesDisabled(), true);
    }

    function test_Receive_RevertWhen_EthSent() public {
        vm.startPrank(deployer);
        vm.expectRevert();
        address(tokenBeamer).call{value: 1 ether}("");
    }

    function testFuzz_setTipRecipient(address payable newTipRecipient) public {
        vm.startPrank(deployer);
        vm.assume(newTipRecipient != address(0));
        tokenBeamer.setTipRecipient(newTipRecipient);
        address storageTipRecipient = abi.decode(abi.encode(vm.load(proxy, 0x0)), (address));
        assertEq(storageTipRecipient, newTipRecipient);
    }

    function testFuzz_setTipRecipient_RevertWhen_BadInput(address payable newTipRecipient) public {
        vm.startPrank(deployer);
        vm.assume(newTipRecipient != address(0));
        tokenBeamer.setTipRecipient(newTipRecipient);

        vm.expectRevert(TokenBeamer.BadInput.selector);
        tokenBeamer.setTipRecipient(newTipRecipient);

        vm.expectRevert(TokenBeamer.BadInput.selector);
        tokenBeamer.setTipRecipient(payable(address(0)));
    }

    function testFuzz_BeamTokens_ETH_MultipleReceivers(uint256 numberOfTokens, uint256 transferAmount) public {
        vm.assume(transferAmount > 0 && transferAmount <= 2**254);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);
        vm.deal(tokenOwner, numberOfTokens * transferAmount);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint[] memory ids = new uint[](numberOfTokens);
        uint[] memory values = new uint[](numberOfTokens);

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));
            tokens[i] = address(0);
            types[i] = 0;
            ids[i] = 0;
            values[i] = transferAmount;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens{value: numberOfTokens * transferAmount}(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(to[i].balance, transferAmount);
        }
    }

    function testFuzz_BeamTokens_ETH_OneReceiver(uint256 numberOfTokens, uint256 transferAmount) public {
        vm.assume(transferAmount > 0 && transferAmount <= 2**254);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);
        vm.deal(tokenOwner, numberOfTokens * transferAmount);

        address payable[] memory to = new address payable[](1);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint[] memory ids = new uint[](numberOfTokens);
        uint[] memory values = new uint[](numberOfTokens);

        to[0] = payable(receiver);
        for (uint256 i; i < numberOfTokens; i++) {
            tokens[i] = address(0);
            types[i] = 0;
            ids[i] = 0;
            values[i] = transferAmount;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens{value: numberOfTokens * transferAmount}(to, tokens, types, ids, values);

        assertEq(receiver.balance, numberOfTokens * transferAmount);
    }

    function testFuzz_BeamTokens_ERC20_MultipleReceivers(uint256 numberOfTokens, uint256 transferAmount) public {
        vm.assume(transferAmount > 0);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint[] memory ids = new uint[](numberOfTokens);
        uint[] memory values = new uint[](numberOfTokens);

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));
            tokens[i] = address(new MockERC20());
            vm.prank(deployer);
            MockERC20(tokens[i]).mint(tokenOwner, transferAmount);
            vm.prank(tokenOwner);
            MockERC20(tokens[i]).approve(address(tokenBeamer), transferAmount);
            types[i] = 20;
            ids[i] = 0;
            values[i] = transferAmount;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(MockERC20(tokens[i]).balanceOf(to[i]), transferAmount);
        }
    }

    function testFuzz_BeamTokens_ERC20_OneReceiver(uint256 numberOfTokens, uint256 transferAmount) public {
        vm.assume(transferAmount > 0);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);

        address payable[] memory to = new address payable[](1);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint[] memory ids = new uint[](numberOfTokens);
        uint[] memory values = new uint[](numberOfTokens);

        to[0] = payable(receiver);
        for (uint256 i; i < numberOfTokens; i++) {
            tokens[i] = address(new MockERC20());
            vm.prank(deployer);
            MockERC20(tokens[i]).mint(tokenOwner, transferAmount);
            vm.prank(tokenOwner);
            MockERC20(tokens[i]).approve(address(tokenBeamer), transferAmount);
            types[i] = 20;
            ids[i] = 0;
            values[i] = transferAmount;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(MockERC20(tokens[i]).balanceOf(receiver), transferAmount);
        }
    }

    function testFuzz_BeamTokens_ERC721_MultipleERC721_MultipleReceivers(uint256 numberOfTokens) public {
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint[] memory ids = new uint[](numberOfTokens);
        uint[] memory values = new uint[](numberOfTokens);

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));
            tokens[i] = address(new MockERC721());
            vm.prank(deployer);
            MockERC721(tokens[i]).mint(tokenOwner, i+1);
            vm.prank(tokenOwner);
            MockERC721(tokens[i]).approve(address(tokenBeamer), i+1);
            types[i] = 721;
            ids[i] = i+1;
            values[i] = 1;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(MockERC721(tokens[i]).ownerOf(i+1), to[i]);
        }
    }

    function testFuzz_BeamTokens_ERC721_MultipleERC721_OneReceiver(uint256 numberOfTokens) public {
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);

        address payable[] memory to = new address payable[](1);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint[] memory ids = new uint[](numberOfTokens);
        uint[] memory values = new uint[](numberOfTokens);

        to[0] = payable(receiver);
        for (uint256 i; i < numberOfTokens; i++) {
            tokens[i] = address(new MockERC721());
            vm.prank(deployer);
            MockERC721(tokens[i]).mint(tokenOwner, i+1);
            vm.prank(tokenOwner);
            MockERC721(tokens[i]).approve(address(tokenBeamer), i+1);
            types[i] = 721;
            ids[i] = i+1;
            values[i] = 1;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens(to, tokens, types, ids, values);

       for (uint256 i; i < numberOfTokens; i++) {
            assertEq(MockERC721(tokens[i]).ownerOf(i+1), to[0]);
        }
    }

    function testFuzz_BeamTokens_ERC721_SingleERC721_MultipleReceivers(uint256 numberOfTokens) public {
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint[] memory ids = new uint[](numberOfTokens);
        uint[] memory values = new uint[](numberOfTokens);

        address erc721Token = address(new MockERC721());

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));
            tokens[i] = erc721Token;
            vm.prank(deployer);
            MockERC721(erc721Token).mint(tokenOwner, i+1);
            vm.prank(tokenOwner);
            MockERC721(erc721Token).approve(address(tokenBeamer), i+1);
            types[i] = 721;
            ids[i] = i+1;
            values[i] = 1;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(MockERC721(erc721Token).ownerOf(i+1), to[i]);
        }
    }

    function testFuzz_BeamTokens_ERC721_SingleERC721_OneReceiver(uint256 numberOfTokens) public {
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);
        numberOfTokens = 5;

        address payable[] memory to = new address payable[](1);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint[] memory ids = new uint[](numberOfTokens);
        uint[] memory values = new uint[](numberOfTokens);

        address erc721Token = address(new MockERC721());
        to[0] = payable(receiver);
        for (uint256 i; i < numberOfTokens; i++) {
            tokens[i] = erc721Token;
            vm.prank(deployer);
            MockERC721(erc721Token).mint(tokenOwner, i+1);
            vm.prank(tokenOwner);
            MockERC721(erc721Token).approve(address(tokenBeamer), i+1);
            types[i] = 721;
            ids[i] = i+1;
            values[i] = 1;
        }
        
        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(MockERC721(erc721Token).ownerOf(i+1), to[0]);
        }
    }
}
