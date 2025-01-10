// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";

contract VeggiaERC721FreeMintTest is Test {
    VeggiaERC721 public veggia;

    function setUp() public {
        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        veggia.initialize(
            address(this), address(this), address(vm.envAddress("SERVER_SIGNER")), "http://localhost:4000/"
        );

        assertEq(veggia.owner(), address(this));
        assertEq(veggia.feeReceiver(), address(this));
        assertEq(veggia.signer(), address(vm.envAddress("SERVER_SIGNER")));
    }

    function test_mintWithSignature() public {
        // message
        bytes memory message =
            hex"000000000000000000000000b3306534236f12dcf2190488e046a359c9167fb00000000000000000000000000000000000000000000000000000000000000000";
        (address to, uint256 index) = abi.decode(message, (address, uint256));
        assertEq(to, address(0xb3306534236F12dCF2190488E046A359C9167FB0));
        assertEq(index, 0);

        // signature
        bytes memory signature =
            hex"772c452400b0d710c66df5cb106a83fdc617c6a8ee01a4b1006ec01b58a74bb10598cb44468026dc3fba9b4886c0023e00c7effca648f2f4ce1f337302b8b3bf1b";

        // mint
        vm.prank(to);
        veggia.mintWithSignature(signature, message);
    }
}
