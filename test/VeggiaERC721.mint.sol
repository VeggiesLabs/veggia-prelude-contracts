// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";

contract VeggiaERC721Mint3Test is Test {
    VeggiaERC721 public veggia;

    function setUp() public {
        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        veggia.initialize(address(this), address(this), serverSigner, "http://localhost:4000/");
    }

    function test_mint() public {
        // 1. buy a caps
        assertEq(veggia.capsBalanceOf(address(this)), 0);
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);

        uint256 threeCapsPrice = veggia.capsPriceByQuantity(3);
        veggia.buyCaps{value: threeCapsPrice}(false, 1);

        assertEq(veggia.capsBalanceOf(address(this)), 1);
        assertEq(veggia.paidCapsBalanceOf(address(this)), 1);

        // 2. Open the caps (mint 3 tokens)
    }
}
