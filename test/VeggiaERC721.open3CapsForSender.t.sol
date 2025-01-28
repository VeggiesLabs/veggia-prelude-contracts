// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";

contract VeggiaERC721Open3CapsForSenderTest is Test {
    VeggiaERC721 public veggia;

    function setUp() public {
        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        veggia.initialize(address(this), address(0x1234), serverSigner, "http://localhost:4000/");
    }

    function test_freeMint3TokenIdIncrease() public {
        vm.warp(block.timestamp + veggia.freeMintCooldown());

        uint256 tokenIdBefore = veggia.tokenId();

        veggia.freeMint3();

        uint256 tokenIdAfter = veggia.tokenId();

        assertEq(tokenIdAfter, tokenIdBefore + 3);
    }

    function test_freeMint3() public {
        vm.warp(block.timestamp + veggia.freeMintCooldown());

        uint256 balanceBefore = veggia.balanceOf(address(this));

        vm.expectEmit(true, true, true, true);
        emit VeggiaERC721.CapsOpened(address(this), 0, false, false);
        vm.expectEmit(true, true, true, true);
        emit VeggiaERC721.CapsOpened(address(this), 1, false, false);
        vm.expectEmit(true, true, true, true);
        emit VeggiaERC721.CapsOpened(address(this), 2, false, false);
        veggia.freeMint3();

        uint256 balanceAfter = veggia.balanceOf(address(this));

        assertEq(balanceAfter, balanceBefore + 3);
        assertEq(veggia.capsBalanceOf(address(this)), 0);
    }

    function test_mint3() public {
        assertEq(veggia.capsBalanceOf(address(this)), 0);
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);

        uint256 threeCapsPrice = veggia.capsPriceByQuantity(3);
        veggia.buyCaps{value: threeCapsPrice}(false, 3);

        assertEq(veggia.capsBalanceOf(address(this)), 3);
        assertEq(veggia.paidCapsBalanceOf(address(this)), 3);

        vm.expectEmit(true, true, true, true);
        emit VeggiaERC721.CapsOpened(address(this), 0, false, false);
        vm.expectEmit(true, true, true, true);
        emit VeggiaERC721.CapsOpened(address(this), 1, false, false);
        vm.expectEmit(true, true, true, true);
        emit VeggiaERC721.CapsOpened(address(this), 2, false, false);
        veggia.mint3(false);

        assertEq(veggia.capsBalanceOf(address(this)), 0);
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);

        assertEq(veggia.balanceOf(address(this)), 3);
    }

    function test_mint3Premium() public {
        assertEq(veggia.capsBalanceOf(address(this)), 0);
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0);

        uint256 threePremiumCapsPrice = veggia.premiumCapsPriceByQuantity(3);
        veggia.buyCaps{value: threePremiumCapsPrice}(true, 3);

        assertEq(veggia.capsBalanceOf(address(this)), 3);
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 3);

        vm.expectEmit(true, true, true, true);
        emit VeggiaERC721.CapsOpened(address(this), 0, true, false);
        vm.expectEmit(true, true, true, true);
        emit VeggiaERC721.CapsOpened(address(this), 1, true, false);
        vm.expectEmit(true, true, true, true);
        emit VeggiaERC721.CapsOpened(address(this), 2, true, false);
        veggia.mint3(true);

        assertEq(veggia.capsBalanceOf(address(this)), 0);
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0);

        assertEq(veggia.balanceOf(address(this)), 3);
    }

    function test_mint3WithSignature(string memory random, uint256 index, bool isPremium, address user) public {
        vm.assume(user != address(0));
        (address serverSigner, uint256 signer) = makeAddrAndKey(random);

        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        veggia.initialize(address(this), address(this), serverSigner, "http://localhost:4000/");
        assertEq(veggia.capsSigner(), serverSigner);

        bytes memory message = abi.encode(user, index, isPremium);
        bytes32 messageHash = keccak256(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(signer), messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertEq(veggia.balanceOf(user), 0);
        assertEq(veggia.tokenId(), 0);

        vm.expectEmit(true, true, true, true);
        emit VeggiaERC721.CapsOpened(user, 0, isPremium, false);
        vm.expectEmit(true, true, true, true);
        emit VeggiaERC721.CapsOpened(user, 1, isPremium, false);
        vm.expectEmit(true, true, true, true);
        emit VeggiaERC721.CapsOpened(user, 2, isPremium, false);

        vm.expectEmit(true, true, false, true);
        emit VeggiaERC721.MintedWithSignature(user, message, signature);

        vm.prank(user);
        veggia.mint3WithSignature(signature, message);

        assertEq(veggia.balanceOf(user), 3);
        assertEq(veggia.tokenId(), 3);
    }
}
