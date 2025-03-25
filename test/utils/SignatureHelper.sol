// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {VeggiaERC721} from "../../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "../utils/constants.sol";
import {Vm} from "forge-std/Vm.sol";

library SignatureHelper {
    bytes32 private constant MINTREQUEST_TYPEHASH = keccak256("MintRequest(address to,uint256 index,bool isPremium)");

    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm internal constant vm = Vm(VM_ADDRESS);

    function signMint3(VeggiaERC721 veggia, address to, bool isPremium, uint256 index)
        public
        view
        returns (bytes memory signature)
    {
        return signMint3As(veggia, SERVER_SIGNER, to, isPremium, index);
    }

    function signMint3As(VeggiaERC721 veggia, bytes32 signer, address to, bool isPremium, uint256 index)
        public
        view
        returns (bytes memory signature)
    {
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Veggia")),
                keccak256(bytes("1")),
                block.chainid,
                address(veggia)
            )
        );

        // Compute the struct hash for MintRequest (with isPremium = false)
        bytes32 structHash = keccak256(abi.encode(MINTREQUEST_TYPEHASH, to, index, isPremium));

        // Compute the EIP712 digest: "\x19\x01" ‖ DOMAIN_SEPARATOR ‖ structHash
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(signer), digest);
        signature = abi.encodePacked(r, s, v);

        return signature;
    }
}
