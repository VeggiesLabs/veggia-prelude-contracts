// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {VeggiaERC721} from "../../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "../utils/constants.sol";
import {Vm} from "forge-std/Vm.sol";
import {SignatureHelper} from "./SignatureHelper.sol";

library MintHelper {
    bytes32 private constant MINTREQUEST_TYPEHASH = keccak256("MintRequest(address to,uint256 index,bool isPremium)");

    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm internal constant vm = Vm(VM_ADDRESS);

    function forceMint3(VeggiaERC721 veggia, address to, uint256 amount) public {
        _forceMint3(veggia, to, amount, false);
    }

    function forceMint3Premium(VeggiaERC721 veggia, address to, uint256 amount) public {
        _forceMint3(veggia, to, amount, true);
    }

    function _forceMint3(VeggiaERC721 veggia, address to, uint256 amount, bool isPremium) private {
        for (uint256 i = 0; i < amount; i++) {
            uint256 index = uint256(keccak256(abi.encodePacked(i, block.timestamp)));
            VeggiaERC721.MintRequest memory req = VeggiaERC721.MintRequest(to, index, isPremium);

            bytes memory signature = SignatureHelper.signMint3(veggia, to, isPremium, index);

            vm.prank(to);
            veggia.mint3WithSignature(req, signature);
            vm.warp(block.timestamp + 1);
        }
    }
}
