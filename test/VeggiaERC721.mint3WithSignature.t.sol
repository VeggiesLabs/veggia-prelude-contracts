// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";

contract VeggiaERC721MintWithSignatureTest is Test {
    VeggiaERC721 public veggia;

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

        vm.expectEmit(true, true, false, true);
        emit VeggiaERC721.MintedWithSignature(user, message, signature);
        vm.prank(user);
        veggia.mint3WithSignature(signature, message);

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

        bytes memory message = abi.encode(user, index, isPremium);
        bytes32 messageHash = keccak256(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(signer), messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertEq(veggia.balanceOf(user), 0);
        assertEq(veggia.tokenId(), 0);

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INVALID_SIGNATURE.selector));
        vm.prank(user);
        veggia.mint3WithSignature(signature, message);

        assertEq(veggia.balanceOf(user), 0);
        assertEq(veggia.tokenId(), 0);
    }

    function test_MintWithSignatureReusedSignature(string memory random, uint256 index, bool isPremium, address user)
        public
    {
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

        vm.prank(user);
        veggia.mint3WithSignature(signature, message);

        assertEq(veggia.balanceOf(user), 3);
        assertEq(veggia.tokenId(), 3);

        // Reuse signature
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.SIGNATURE_REUSED.selector));
        vm.prank(user);
        veggia.mint3WithSignature(signature, message);
    }

    function test_MintWithSignatureInvalidSender(string memory random, uint256 index, bool isPremium, address user)
        public
    {
        vm.assume(user != address(0));

        (address serverSigner, uint256 signer) = makeAddrAndKey(random);

        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        veggia.initialize(address(this), address(this), serverSigner, "http://localhost:4000/");
        assertEq(veggia.capsSigner(), serverSigner);

        bytes memory message = abi.encode(user, index, isPremium);
        address invalidSender = address(0x1234);
        bytes32 messageHash = keccak256(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(signer), messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertEq(veggia.balanceOf(user), 0);
        assertEq(veggia.balanceOf(invalidSender), 0);
        assertEq(veggia.tokenId(), 0);

        // Try to use the signature with a msg.sender != user
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INVALID_SENDER.selector, invalidSender, user));
        vm.prank(invalidSender);
        veggia.mint3WithSignature(signature, message);

        assertEq(veggia.balanceOf(user), 0);
        assertEq(veggia.balanceOf(invalidSender), 0);
        assertEq(veggia.tokenId(), 0);
    }

    function test_raw_mint3WithSignature() public {
        address serverSigner = 0x2f9e4Ffc85257247e9061A3EE9d3b6b23eF560E9;
        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        veggia.initialize(address(this), address(this), serverSigner, "http://localhost:4000/");
        assertEq(veggia.capsSigner(), serverSigner);

        // message
        bytes memory message =
            hex"000000000000000000000000e5af443d0f924e31a19b2286f8df3c60de97963dfa5920d307f7bf370eda6b4ce25abc6b757e5e47558c05b611e05832eafb0cee0000000000000000000000000000000000000000000000000000000000000000";
        (address to, uint256 index) = abi.decode(message, (address, uint256));
        assertEq(to, address(0xE5aF443D0F924E31a19b2286F8DF3c60dE97963D));
        assertEq(index, uint256(0xfa5920d307f7bf370eda6b4ce25abc6b757e5e47558c05b611e05832eafb0cee));

        // signature
        bytes memory signature =
            hex"79477f1c5e288bbe48e8571544ad47bb903d35feb4ec25230d7ddd9b2ac38b2d4864e90af6a3a59bc95ad6d42589259f411b80f4f5a155e049e6b5dd9f630fc21c";

        // mint
        vm.prank(to);
        veggia.mint3WithSignature(signature, message);
    }
}
