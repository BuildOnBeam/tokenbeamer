// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {TokenBeamer} from "../contracts/TokenBeamer.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {MockERC20} from "./MockERC20.sol";
import {MockERC721} from "./MockERC721.sol";
import {MockERC1155} from "./MockERC1155.sol";

contract TokenBeamerTest is Test {
    string internal mnemonic = "test test test test test test test test test test test junk";
    address internal deployer;
    address internal tokenOwner;
    address internal receiver;
    address internal operator;

    TokenBeamer internal tokenBeamer;
    address internal implementation;
    address internal proxy;

    MockERC20 internal mockERC20;
    MockERC721 internal mockERC721;
    MockERC1155 internal mockERC1155;

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

        implementation = address(new TokenBeamer());

        proxy =
            address(new TransparentUpgradeableProxy(implementation, deployer, abi.encodeWithSignature("initialize()")));

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
        (bool success, bytes memory data) = address(tokenBeamer).call{value: 1 ether}("");
        (success);
        (data);
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
        vm.assume(transferAmount > 0 && transferAmount <= 2 ** 250);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);
        vm.deal(tokenOwner, numberOfTokens * transferAmount);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

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
        vm.assume(transferAmount > 0 && transferAmount <= 2 ** 250);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);
        vm.deal(tokenOwner, numberOfTokens * transferAmount);

        address payable[] memory to = new address payable[](1);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

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
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

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
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

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
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));
            tokens[i] = address(new MockERC721());
            vm.prank(deployer);
            MockERC721(tokens[i]).mint(tokenOwner, i + 1);
            vm.prank(tokenOwner);
            MockERC721(tokens[i]).approve(address(tokenBeamer), i + 1);
            types[i] = 721;
            ids[i] = i + 1;
            values[i] = 1;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(MockERC721(tokens[i]).ownerOf(i + 1), to[i]);
        }
    }

    function testFuzz_BeamTokens_ERC721_MultipleERC721_OneReceiver(uint256 numberOfTokens) public {
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);

        address payable[] memory to = new address payable[](1);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        to[0] = payable(receiver);
        for (uint256 i; i < numberOfTokens; i++) {
            tokens[i] = address(new MockERC721());
            vm.prank(deployer);
            MockERC721(tokens[i]).mint(tokenOwner, i + 1);
            vm.prank(tokenOwner);
            MockERC721(tokens[i]).approve(address(tokenBeamer), i + 1);
            types[i] = 721;
            ids[i] = i + 1;
            values[i] = 1;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(MockERC721(tokens[i]).ownerOf(i + 1), to[0]);
        }
    }

    function testFuzz_BeamTokens_ERC721_SingleERC721_MultipleReceivers(uint256 numberOfTokens) public {
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        address erc721Token = address(new MockERC721());

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));
            tokens[i] = erc721Token;
            vm.prank(deployer);
            MockERC721(erc721Token).mint(tokenOwner, i + 1);
            vm.prank(tokenOwner);
            MockERC721(erc721Token).approve(address(tokenBeamer), i + 1);
            types[i] = 721;
            ids[i] = i + 1;
            values[i] = 1;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(MockERC721(erc721Token).ownerOf(i + 1), to[i]);
        }
    }

    function testFuzz_BeamTokens_ERC721_SingleERC721_OneReceiver(uint256 numberOfTokens) public {
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);

        address payable[] memory to = new address payable[](1);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        address erc721Token = address(new MockERC721());
        to[0] = payable(receiver);
        for (uint256 i; i < numberOfTokens; i++) {
            tokens[i] = erc721Token;
            vm.prank(deployer);
            MockERC721(erc721Token).mint(tokenOwner, i + 1);
            vm.prank(tokenOwner);
            MockERC721(erc721Token).approve(address(tokenBeamer), i + 1);
            types[i] = 721;
            ids[i] = i + 1;
            values[i] = 1;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(MockERC721(erc721Token).ownerOf(i + 1), to[0]);
        }
    }

    function testFuzz_BeamTokens_ERC1155_MultipleERC1155_MultipleReceivers(
        uint256 numberOfTokens,
        uint256 transferAmount
    ) public {
        vm.assume(transferAmount > 0);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));
            tokens[i] = address(new MockERC1155());
            vm.prank(deployer);
            MockERC1155(tokens[i]).mint(tokenOwner, i + 1, transferAmount);
            vm.prank(tokenOwner);
            MockERC1155(tokens[i]).setApprovalForAll(address(tokenBeamer), true);
            types[i] = 1155;
            ids[i] = i + 1;
            values[i] = transferAmount;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(MockERC1155(tokens[i]).balanceOf(to[i], i + 1), transferAmount);
        }
    }

    function testFuzz_BeamTokens_ERC1155_MultipleERC1155_OneReceiver(uint256 numberOfTokens, uint256 transferAmount)
        public
    {
        vm.assume(transferAmount > 0);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);

        address payable[] memory to = new address payable[](1);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        to[0] = payable(receiver);
        for (uint256 i; i < numberOfTokens; i++) {
            tokens[i] = address(new MockERC1155());
            vm.prank(deployer);
            MockERC1155(tokens[i]).mint(tokenOwner, i + 1, transferAmount);
            vm.prank(tokenOwner);
            MockERC1155(tokens[i]).setApprovalForAll(address(tokenBeamer), true);
            types[i] = 1155;
            ids[i] = i + 1;
            values[i] = transferAmount;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(MockERC1155(tokens[i]).balanceOf(to[0], i + 1), transferAmount);
        }
    }

    function testFuzz_BeamTokens_ERC1155_SingleERC1155_MultipleReceivers(uint256 numberOfTokens, uint256 transferAmount)
        public
    {
        vm.assume(transferAmount > 0);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        address erc721Token = address(new MockERC1155());

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));
            tokens[i] = erc721Token;
            vm.prank(deployer);
            MockERC1155(erc721Token).mint(tokenOwner, i + 1, transferAmount);
            vm.prank(tokenOwner);
            MockERC1155(erc721Token).setApprovalForAll(address(tokenBeamer), true);
            types[i] = 1155;
            ids[i] = i + 1;
            values[i] = transferAmount;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(MockERC1155(erc721Token).balanceOf(to[i], i + 1), transferAmount);
        }
    }

    function testFuzz_BeamTokens_ERC1155_SingleERC1155_OneReceiver(uint256 numberOfTokens, uint256 transferAmount)
        public
    {
        vm.assume(transferAmount > 0);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);

        address payable[] memory to = new address payable[](1);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        address erc721Token = address(new MockERC1155());
        to[0] = payable(receiver);

        for (uint256 i; i < numberOfTokens; i++) {
            tokens[i] = erc721Token;
            vm.prank(deployer);
            MockERC1155(erc721Token).mint(tokenOwner, i + 1, transferAmount);
            vm.prank(tokenOwner);
            MockERC1155(erc721Token).setApprovalForAll(address(tokenBeamer), true);
            types[i] = 1155;
            ids[i] = i + 1;
            values[i] = transferAmount;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(MockERC1155(erc721Token).balanceOf(to[0], i + 1), transferAmount);
        }
    }

    function testFuzz_BeamTokens_AllTokens(uint256 numberOfTokens, uint256 transferAmount) public {
        vm.assume(transferAmount > 0 && transferAmount <= 2 ** 250);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 50);
        numberOfTokens = 4 * numberOfTokens;
        vm.deal(tokenOwner, (numberOfTokens / 4) * transferAmount);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        uint256 nativeAmount;

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));

            if (i % 4 == 0) {
                tokens[i] = address(0);
                types[i] = 0;
                values[i] = transferAmount;
                nativeAmount += transferAmount;
            } else if (i % 4 == 1) {
                tokens[i] = address(new MockERC20());
                vm.prank(deployer);
                MockERC20(tokens[i]).mint(tokenOwner, transferAmount);
                vm.prank(tokenOwner);
                MockERC20(tokens[i]).approve(address(tokenBeamer), transferAmount);
                types[i] = 20;
                values[i] = transferAmount;
            } else if (i % 4 == 2) {
                tokens[i] = address(new MockERC721());
                vm.prank(deployer);
                MockERC721(tokens[i]).mint(tokenOwner, i + 1);
                vm.prank(tokenOwner);
                MockERC721(tokens[i]).approve(address(tokenBeamer), i + 1);
                types[i] = 721;
                values[i] = 1;
            } else {
                tokens[i] = address(new MockERC1155());
                vm.prank(deployer);
                MockERC1155(tokens[i]).mint(tokenOwner, i + 1, transferAmount);
                vm.prank(tokenOwner);
                MockERC1155(tokens[i]).setApprovalForAll(address(tokenBeamer), true);
                types[i] = 1155;
                values[i] = transferAmount;
            }

            ids[i] = i + 1;
        }

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens{value: (numberOfTokens / 4) * transferAmount}(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            if (i % 4 == 0) {
                assertEq(to[i].balance, transferAmount);
            } else if (i % 4 == 1) {
                assertEq(MockERC20(tokens[i]).balanceOf(to[i]), transferAmount);
            } else if (i % 4 == 2) {
                assertEq(MockERC721(tokens[i]).ownerOf(i + 1), to[i]);
            } else {
                assertEq(MockERC1155(tokens[i]).balanceOf(to[i], i + 1), transferAmount);
            }
        }
    }

    function testFuzz_BeamTokens_RevertWhen_BadInput(uint256 numberOfTokens, uint256 transferAmount) public {
        vm.assume(transferAmount > 0 && transferAmount <= 2 ** 250);
        vm.assume(numberOfTokens > 1 && numberOfTokens <= 100);
        vm.deal(tokenOwner, numberOfTokens * transferAmount);

        address payable[] memory to = new address payable[](numberOfTokens);
        // Set an invalid tokens array
        address[] memory tokens = new address[](0);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));
            types[i] = 0;
            ids[i] = 0;
            values[i] = transferAmount;
        }

        vm.startPrank(tokenOwner);
        vm.expectRevert(TokenBeamer.BadInput.selector);
        tokenBeamer.beamTokens{value: numberOfTokens * transferAmount}(to, tokens, types, ids, values);
    }

    function testFuzz_BeamTokens_TransferTips(uint256 numberOfTokens, uint256 transferAmount, uint256 tipAmount)
        public
    {
        vm.assume(transferAmount > 0 && transferAmount <= 2 ** 250);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);
        vm.assume(tipAmount > 0 && tipAmount <= 1e18);
        vm.deal(tokenOwner, numberOfTokens * transferAmount + tipAmount);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));
            tokens[i] = address(0);
            types[i] = 0;
            ids[i] = 0;
            values[i] = transferAmount;
        }

        uint256 tipRecipientBalance = address(deployer).balance;

        vm.startPrank(tokenOwner);
        tokenBeamer.beamTokens{value: numberOfTokens * transferAmount + tipAmount}(to, tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(to[i].balance, transferAmount);
        }

        assertEq(address(deployer).balance, tipRecipientBalance + tipAmount);
    }

    function testFuzz_ProcessTransfer_RevertWhen_BadInput(uint256 numberOfTokens, uint256 transferAmount) public {
        vm.assume(transferAmount > numberOfTokens && transferAmount <= 2 ** 250);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);
        vm.deal(tokenOwner, numberOfTokens * transferAmount);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(0));
            tokens[i] = address(0);
            types[i] = 0;
            ids[i] = 0;
            values[i] = transferAmount;
        }

        vm.startPrank(tokenOwner);
        vm.expectRevert(TokenBeamer.BadInput.selector);
        tokenBeamer.beamTokens{value: numberOfTokens * transferAmount}(to, tokens, types, ids, values);
    }

    function testFuzz_ProcessTransfer_RevertWhen_UnsupportedTokenType(uint256 numberOfTokens, uint256 transferAmount)
        public
    {
        vm.assume(transferAmount > numberOfTokens && transferAmount <= 2 ** 250);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 100);
        vm.deal(tokenOwner, numberOfTokens * transferAmount);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));
            tokens[i] = address(0);
            types[i] = 1000;
            ids[i] = 0;
            values[i] = transferAmount;
        }

        vm.startPrank(tokenOwner);
        vm.expectRevert(abi.encodeWithSelector(TokenBeamer.UnsupportedTokenType.selector, 1000));
        tokenBeamer.beamTokens{value: numberOfTokens * transferAmount}(to, tokens, types, ids, values);
    }

    function testFuzz_GetApprovals_AllTokens(uint256 numberOfTokens, uint256 transferAmount) public {
        vm.assume(transferAmount > 0 && transferAmount <= 2 ** 250);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 50);
        numberOfTokens = 4 * numberOfTokens;
        vm.deal(tokenOwner, (numberOfTokens / 4) * transferAmount);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        uint256 nativeAmount;

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));

            if (i % 4 == 0) {
                tokens[i] = address(0);
                types[i] = 0;
                values[i] = transferAmount;
                nativeAmount += transferAmount;
            } else if (i % 4 == 1) {
                tokens[i] = address(new MockERC20());
                vm.prank(deployer);
                MockERC20(tokens[i]).mint(tokenOwner, transferAmount);
                vm.prank(tokenOwner);
                MockERC20(tokens[i]).approve(address(tokenBeamer), transferAmount);
                types[i] = 20;
                values[i] = transferAmount;
            } else if (i % 4 == 2) {
                tokens[i] = address(new MockERC721());
                vm.prank(deployer);
                MockERC721(tokens[i]).mint(tokenOwner, i + 1);
                vm.prank(tokenOwner);
                MockERC721(tokens[i]).approve(address(tokenBeamer), i + 1);
                types[i] = 721;
                values[i] = 1;
            } else {
                tokens[i] = address(new MockERC1155());
                vm.prank(deployer);
                MockERC1155(tokens[i]).mint(tokenOwner, i + 1, transferAmount);
                vm.prank(tokenOwner);
                MockERC1155(tokens[i]).setApprovalForAll(address(tokenBeamer), true);
                types[i] = 1155;
                values[i] = transferAmount;
            }

            ids[i] = i + 1;
        }

        bool[] memory approvalStates = new bool[](numberOfTokens);
        approvalStates = tokenBeamer.getApprovals(tokenOwner, address(tokenBeamer), tokens, types, ids, values);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(approvalStates[i], true);
        }
    }

    function testFuzz_GetApprovals_NFTsWithoutIds(uint256 numberOfTokens, uint256 transferAmount) public {
        vm.assume(transferAmount > 0 && transferAmount <= 2 ** 250);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 50);
        numberOfTokens = 2 * numberOfTokens;
        vm.deal(tokenOwner, (numberOfTokens / 2) * transferAmount);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));
            
            if (i % 2 == 0) {
                tokens[i] = address(new MockERC721());
                vm.prank(deployer);
                MockERC721(tokens[i]).mint(tokenOwner, i + 1);
                vm.prank(tokenOwner);
                MockERC721(tokens[i]).setApprovalForAll(address(tokenBeamer), true);
                types[i] = 721;
                values[i] = 1;
            } else {
                tokens[i] = address(new MockERC1155());
                vm.prank(deployer);
                MockERC1155(tokens[i]).mint(tokenOwner, i + 1, transferAmount);
                vm.prank(tokenOwner);
                MockERC1155(tokens[i]).setApprovalForAll(address(tokenBeamer), true);
                types[i] = 1155;
                values[i] = transferAmount;
            }

            ids[i] = i + 1;
        }

        bool[] memory approvalStates = new bool[](numberOfTokens);

        uint256[] memory emptyIds = new uint256[](0);
        approvalStates = tokenBeamer.getApprovals(tokenOwner, address(tokenBeamer), tokens, types, emptyIds, values);
        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(approvalStates[i], true);
        }
    }

    function testFuzz_GetApprovals_NFTsWithIds(uint256 numberOfTokens, uint256 transferAmount) public {
        vm.assume(transferAmount > 0 && transferAmount <= 2 ** 250);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 50);
        numberOfTokens = 2 * numberOfTokens;
        vm.deal(tokenOwner, (numberOfTokens / 2) * transferAmount);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));
            
            if (i % 2 == 0) {
                tokens[i] = address(new MockERC721());
                vm.prank(deployer);
                MockERC721(tokens[i]).mint(tokenOwner, i + 1);
                vm.prank(tokenOwner);
                MockERC721(tokens[i]).setApprovalForAll(address(tokenBeamer), true);
                types[i] = 721;
                values[i] = 1;
            } else {
                tokens[i] = address(new MockERC1155());
                vm.prank(deployer);
                MockERC1155(tokens[i]).mint(tokenOwner, i + 1, transferAmount);
                vm.prank(tokenOwner);
                MockERC1155(tokens[i]).setApprovalForAll(address(tokenBeamer), true);
                types[i] = 1155;
                values[i] = transferAmount;
            }

            ids[i] = i + 1;
        }

        bool[] memory approvalStates = new bool[](numberOfTokens);

        uint16[] memory emptyTypes = new uint16[](0);
        approvalStates = tokenBeamer.getApprovals(tokenOwner, address(tokenBeamer), tokens, emptyTypes, ids, values);
        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(approvalStates[i], true);
        }
    }

    function testFuzz_GetApprovals_NoValue(uint256 numberOfTokens, uint256 transferAmount) public {
        vm.assume(transferAmount > 0 && transferAmount <= 2 ** 250);
        vm.assume(numberOfTokens > 0 && numberOfTokens <= 50);
        numberOfTokens = 3 * numberOfTokens;
        vm.deal(tokenOwner, (numberOfTokens / 3) * transferAmount);

        address payable[] memory to = new address payable[](numberOfTokens);
        address[] memory tokens = new address[](numberOfTokens);
        uint16[] memory types = new uint16[](numberOfTokens);
        uint256[] memory ids = new uint256[](numberOfTokens);
        uint256[] memory values = new uint256[](numberOfTokens);

        for (uint256 i; i < numberOfTokens; i++) {
            to[i] = payable(address(uint160(uint160(receiver) + i)));
            
            if (i % 3 == 0) {
                tokens[i] = address(new MockERC20());
                vm.prank(deployer);
                MockERC20(tokens[i]).mint(tokenOwner, transferAmount);
                vm.prank(tokenOwner);
                MockERC20(tokens[i]).approve(address(tokenBeamer), transferAmount);
                types[i] = 20;
                values[i] = transferAmount;
            } else if (i % 3 == 1) {
                tokens[i] = address(new MockERC721());
                vm.prank(deployer);
                MockERC721(tokens[i]).mint(tokenOwner, i + 1);
                vm.prank(tokenOwner);
                MockERC721(tokens[i]).approve(address(tokenBeamer), i + 1);
                types[i] = 721;
                values[i] = 1;
            } else {
                tokens[i] = address(new MockERC1155());
                vm.prank(deployer);
                MockERC1155(tokens[i]).mint(tokenOwner, i + 1, transferAmount);
                vm.prank(tokenOwner);
                MockERC1155(tokens[i]).setApprovalForAll(address(tokenBeamer), true);
                types[i] = 1155;
                values[i] = transferAmount;
            }

            ids[i] = i + 1;
        }

        bool[] memory approvalStates = new bool[](numberOfTokens);
        uint256[] memory emptyValue = new uint256[](0);

        approvalStates = tokenBeamer.getApprovals(tokenOwner, address(tokenBeamer), tokens, types, ids, emptyValue);

        for (uint256 i; i < numberOfTokens; i++) {
            assertEq(approvalStates[i], true);
        }
    }

    function test_GetApprovals_RevertWhen_BadInput() public {
        vm.startPrank(tokenOwner);
        vm.expectRevert(TokenBeamer.BadInput.selector);
        tokenBeamer.getApprovals(tokenOwner, address(tokenBeamer), new address[](0), new uint16[](0), new uint256[](0), new uint256[](0));
    }

    function test_GetApprovals_RevertWhen_UnsupportedTokenType() public {
        vm.startPrank(tokenOwner);

        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        uint16[] memory types = new uint16[](1);
        types[0] = 123;
        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory values = new uint256[](1);
        values[0] = 1;

        vm.expectRevert(abi.encodeWithSelector(TokenBeamer.UnsupportedTokenType.selector, types[0]));
        tokenBeamer.getApprovals(tokenOwner, address(tokenBeamer), tokens, types, ids, values);
    }

    function testFuzz_RecoverFunds() public {
        vm.startPrank(tokenOwner);

        uint256 contractBalanceBefore = address(tokenBeamer).balance;
        uint256 tokenOwnerBalanceBefore = address(tokenOwner).balance;

        uint256 amount = 100 wei;
        vm.deal(address(tokenBeamer), amount);

        assertEq(address(tokenBeamer).balance, contractBalanceBefore + amount);

        vm.stopPrank();
        vm.startPrank(deployer);

        tokenBeamer.recoverFunds(payable(tokenOwner), address(0), 0, 0, amount);

        assertEq(address(tokenBeamer).balance, contractBalanceBefore);
        assertEq(tokenOwner.balance, tokenOwnerBalanceBefore + amount);
    }
}