// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {SignatureHelper} from "./utils/SignatureHelper.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract VeggiaERC721MintWithSignatureTest is Test, ERC721Holder {
    VeggiaERC721 public veggia;

    function test_mint3WithSignature(string memory random, uint256 index, bool isPremium, address user) public {
        vm.assume(user != address(0));
        vm.assume(user.code.length == 0);
        (address serverSigner, uint256 signer) = makeAddrAndKey(random);

        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        veggia.initialize(address(this), address(this), serverSigner, "http://localhost:4000/");
        assertEq(veggia.capsSigner(), serverSigner);

        VeggiaERC721.MintRequest memory req = VeggiaERC721.MintRequest(user, index, isPremium);
        bytes memory signature = SignatureHelper.signMint3As(veggia, bytes32(signer), user, isPremium, index);

        assertEq(veggia.balanceOf(user), 0);
        assertEq(veggia.tokenId(), 0);

        vm.expectEmit(true, true, false, true);
        emit VeggiaERC721.MintedWithSignature(user, req, signature);
        vm.prank(user);
        veggia.mint3WithSignature(req, signature);

        assertEq(veggia.balanceOf(user), 3);
        assertEq(veggia.tokenId(), 3);
    }

    function test_MintWithSignatureWrongSigner(string memory random, uint256 index, bool isPremium, address user)
        public
    {
        vm.assume(user != address(0));
        (, uint256 signer) = makeAddrAndKey(random);

        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        veggia.initialize(address(this), address(this), address(0x1234), "http://localhost:4000/");

        VeggiaERC721.MintRequest memory req = VeggiaERC721.MintRequest(user, index, isPremium);
        bytes memory signature = SignatureHelper.signMint3As(veggia, bytes32(signer), user, isPremium, index);

        assertEq(veggia.balanceOf(user), 0);
        assertEq(veggia.tokenId(), 0);

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INVALID_SIGNATURE.selector));
        vm.prank(user);
        veggia.mint3WithSignature(req, signature);

        assertEq(veggia.balanceOf(user), 0);
        assertEq(veggia.tokenId(), 0);
    }

    function test_MintWithSignatureReusedSignature(string memory random, uint256 index, bool isPremium, address user)
        public
    {
        vm.assume(user != address(0));
        vm.assume(user.code.length == 0);

        (address serverSigner, uint256 signer) = makeAddrAndKey(random);

        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        veggia.initialize(address(this), address(this), serverSigner, "http://localhost:4000/");
        assertEq(veggia.capsSigner(), serverSigner);

        VeggiaERC721.MintRequest memory req = VeggiaERC721.MintRequest(user, index, isPremium);
        bytes memory signature = SignatureHelper.signMint3As(veggia, bytes32(signer), user, isPremium, index);

        assertEq(veggia.balanceOf(user), 0);
        assertEq(veggia.tokenId(), 0);

        vm.prank(user);
        veggia.mint3WithSignature(req, signature);

        assertEq(veggia.balanceOf(user), 3);
        assertEq(veggia.tokenId(), 3);

        // Reuse signature
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.SIGNATURE_REUSED.selector));
        vm.prank(user);
        veggia.mint3WithSignature(req, signature);
    }

    function test_MintWithSignatureInvalidSender(string memory random, uint256 index, bool isPremium, address user)
        public
    {
        vm.assume(user != address(0));

        (address serverSigner, uint256 signer) = makeAddrAndKey(random);

        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        veggia.initialize(address(this), address(this), serverSigner, "http://localhost:4000/");
        assertEq(veggia.capsSigner(), serverSigner);

        address invalidSender = address(0x1234);
        VeggiaERC721.MintRequest memory req = VeggiaERC721.MintRequest(user, index, isPremium);
        bytes memory signature = SignatureHelper.signMint3As(veggia, bytes32(signer), user, isPremium, index);

        assertEq(veggia.balanceOf(user), 0);
        assertEq(veggia.balanceOf(invalidSender), 0);
        assertEq(veggia.tokenId(), 0);

        // Try to use the signature with a msg.sender != user
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INVALID_SENDER.selector, invalidSender, user));
        vm.prank(invalidSender);
        veggia.mint3WithSignature(req, signature);

        assertEq(veggia.balanceOf(user), 0);
        assertEq(veggia.balanceOf(invalidSender), 0);
        assertEq(veggia.tokenId(), 0);
    }
}
