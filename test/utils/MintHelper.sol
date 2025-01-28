// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {VeggiaERC721} from "../../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "../utils/constants.sol";
import {Vm} from "forge-std/Vm.sol";

library MintHelper {
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm internal constant vm = Vm(VM_ADDRESS);

    function forceMint(VeggiaERC721 veggia, address to, uint256 amount) public {
        for (uint256 i = 0; i < amount; i++) {
            bytes32 index = keccak256(abi.encodePacked(i, block.timestamp));
            bytes memory message = abi.encode(to, index, false);
            bytes32 messageHash = keccak256(message);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(SERVER_SIGNER), messageHash);
            bytes memory signature = abi.encodePacked(r, s, v);

            vm.prank(to);
            veggia.mint3WithSignature(signature, message);
            vm.warp(block.timestamp + 1);
        }
    }

    function forceMintPremium(VeggiaERC721 veggia, address to, uint256 amount) public {
        for (uint256 i = 0; i < amount; i++) {
            bytes32 index = keccak256(abi.encodePacked(i, block.timestamp));
            bytes memory message = abi.encode(to, index, true);
            bytes32 messageHash = keccak256(message);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(SERVER_SIGNER), messageHash);
            bytes memory signature = abi.encodePacked(r, s, v);

            vm.prank(to);
            veggia.mint3WithSignature(signature, message);
            vm.warp(block.timestamp + 1);
        }
    }
}
