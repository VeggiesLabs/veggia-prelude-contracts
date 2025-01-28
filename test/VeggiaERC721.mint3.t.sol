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
        veggia.initialize(address(this), address(0x1234), serverSigner, "http://localhost:4000/");
    }

    function test_mint3() public {
        assertEq(veggia.capsBalanceOf(address(this)), 0);
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);

        uint256 threeCapsPrice = veggia.capsPriceByQuantity(3);
        veggia.buyCaps{value: threeCapsPrice}(false, 3);

        assertEq(veggia.capsBalanceOf(address(this)), 3);
        assertEq(veggia.paidCapsBalanceOf(address(this)), 3);

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

        veggia.mint3(true);

        assertEq(veggia.capsBalanceOf(address(this)), 0);
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0);

        assertEq(veggia.balanceOf(address(this)), 3);
    }

    function test_mint3WhenBalanceIsUero() public {
        // 1. buy a caps
        assertEq(veggia.capsBalanceOf(address(this)), 0);
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0);

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INSUFFICIENT_CAPS_BALANCE.selector));
        veggia.mint3(true);
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INSUFFICIENT_CAPS_BALANCE.selector));
        veggia.mint3(false);

        assertEq(veggia.capsBalanceOf(address(this)), 0);
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);

        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0);
    }
}
