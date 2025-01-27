// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {MintHelper} from "./utils/MintHelper.sol";

contract VeggiaERC721BuyCapsTest is Test {
    using MintHelper for VeggiaERC721;

    VeggiaERC721 public veggia;

    address feeReceiver = address(0x9999);
    address user = address(0x5555);

    function setUp() public {
        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        veggia.initialize(address(this), feeReceiver, serverSigner, "http://localhost:4000/");

        // Ensure that the caps prices are initialized
        assertTrue(veggia.capsPriceByQuantity(1) != 0);
        assertTrue(veggia.capsPriceByQuantity(3) != 0);
        assertTrue(veggia.capsPriceByQuantity(10) != 0);
        assertTrue(veggia.premiumCapsPriceByQuantity(1) != 0);
        assertTrue(veggia.premiumCapsPriceByQuantity(3) != 0);
        assertTrue(veggia.premiumCapsPriceByQuantity(10) != 0);
    }

    function test_buyOneCaps() public {
        uint256 feeReceiverBalanceBefore = feeReceiver.balance;
        uint256 oneCapsPrice = veggia.capsPriceByQuantity(1);
        assertEq(veggia.capsBalanceOf(user), 0, "capsBalanceOf != 0");
        assertEq(veggia.paidCapsBalanceOf(user), 0, "paidCapsBalanceOf != 0");

        vm.deal(user, oneCapsPrice);
        vm.prank(user);
        veggia.buyCaps{value: oneCapsPrice}(false, 1);

        assertEq(veggia.capsBalanceOf(user), 1, "capsBalanceOf != 1");
        assertEq(veggia.paidCapsBalanceOf(user), 1, "paidCapsBalanceOf != 1");
        assertEq(
            feeReceiver.balance,
            feeReceiverBalanceBefore + oneCapsPrice,
            "balance != feeReceiverBalanceBefore + oneCapsPrice"
        );
    }

    function test_buyThreeCaps() public {
        uint256 feeReceiverBalanceBefore = feeReceiver.balance;
        uint256 threeCapsPrice = veggia.capsPriceByQuantity(3);
        assertEq(veggia.capsBalanceOf(user), 0, "capsBalanceOf != 0");
        assertEq(veggia.paidCapsBalanceOf(user), 0, "paidCapsBalanceOf != 0");

        vm.deal(user, threeCapsPrice);
        vm.prank(user);
        veggia.buyCaps{value: threeCapsPrice}(false, 3);

        assertEq(veggia.capsBalanceOf(user), 3, "capsBalanceOf != 3");
        assertEq(veggia.paidCapsBalanceOf(user), 3, "paidCapsBalanceOf != 3");
        assertEq(
            feeReceiver.balance,
            feeReceiverBalanceBefore + threeCapsPrice,
            "balance != feeReceiverBalanceBefore + threeCapsPrice"
        );
    }

    function test_buyTenCaps() public {
        uint256 feeReceiverBalanceBefore = feeReceiver.balance;
        uint256 tenCapsPrice = veggia.capsPriceByQuantity(10);
        assertEq(veggia.capsBalanceOf(user), 0, "capsBalanceOf != 0");
        assertEq(veggia.paidCapsBalanceOf(user), 0, "paidCapsBalanceOf != 0");

        vm.deal(user, tenCapsPrice);
        vm.prank(user);
        veggia.buyCaps{value: tenCapsPrice}(false, 10);

        assertEq(veggia.capsBalanceOf(user), 10, "capsBalanceOf != 10");
        assertEq(veggia.paidCapsBalanceOf(user), 10, "paidCapsBalanceOf != 10");
        assertEq(
            feeReceiver.balance,
            feeReceiverBalanceBefore + tenCapsPrice,
            "balance != feeReceiverBalanceBefore + tenCapsPrice"
        );
    }

    function test_buyOnePremiumCaps() public {
        uint256 feeReceiverBalanceBefore = feeReceiver.balance;
        uint256 onePremiumCapsPrice = veggia.premiumCapsPriceByQuantity(1);
        assertEq(veggia.capsBalanceOf(user), 0, "capsBalanceOf != 0");
        assertEq(veggia.paidPremiumCapsBalanceOf(user), 0, "paidPremiumCapsBalanceOf != 0");

        vm.deal(user, onePremiumCapsPrice);
        vm.prank(user);
        veggia.buyCaps{value: onePremiumCapsPrice}(true, 1);

        assertEq(veggia.capsBalanceOf(user), 1, "capsBalanceOf != 1");
        assertEq(veggia.paidPremiumCapsBalanceOf(user), 1, "paidPremiumCapsBalanceOf != 1");
        assertEq(
            feeReceiver.balance,
            feeReceiverBalanceBefore + onePremiumCapsPrice,
            "balance != feeReceiverBalanceBefore + onePremiumCapsPrice"
        );
    }

    function test_buyThreePremiumCaps() public {
        uint256 feeReceiverBalanceBefore = feeReceiver.balance;
        uint256 threePremiumCapsPrice = veggia.premiumCapsPriceByQuantity(3);
        assertEq(veggia.capsBalanceOf(user), 0, "capsBalanceOf != 0");
        assertEq(veggia.paidPremiumCapsBalanceOf(user), 0, "paidPremiumCapsBalanceOf != 0");

        vm.deal(user, threePremiumCapsPrice);
        vm.prank(user);
        veggia.buyCaps{value: threePremiumCapsPrice}(true, 3);

        assertEq(veggia.capsBalanceOf(user), 3, "capsBalanceOf != 3");
        assertEq(veggia.paidPremiumCapsBalanceOf(user), 3, "paidPremiumCapsBalanceOf != 3");
        assertEq(
            feeReceiver.balance,
            feeReceiverBalanceBefore + threePremiumCapsPrice,
            "balance != feeReceiverBalanceBefore + threePremiumCapsPrice"
        );
    }

    function test_buyTenPremiumCaps() public {
        uint256 feeReceiverBalanceBefore = feeReceiver.balance;
        uint256 tenPremiumCapsPrice = veggia.premiumCapsPriceByQuantity(10);
        assertEq(veggia.capsBalanceOf(user), 0, "capsBalanceOf != 0");
        assertEq(veggia.paidPremiumCapsBalanceOf(user), 0, "paidPremiumCapsBalanceOf != 0");

        vm.deal(user, tenPremiumCapsPrice);
        vm.prank(user);
        veggia.buyCaps{value: tenPremiumCapsPrice}(true, 10);

        assertEq(veggia.capsBalanceOf(user), 10, "capsBalanceOf != 10");
        assertEq(veggia.paidPremiumCapsBalanceOf(user), 10, "paidPremiumCapsBalanceOf != 10");
        assertEq(
            feeReceiver.balance,
            feeReceiverBalanceBefore + tenPremiumCapsPrice,
            "balance != feeReceiverBalanceBefore + tenPremiumCapsPrice"
        );
    }

    function test_buyUnexpectedAmountOfCaps(uint256 capsAmount) public {
        vm.assume(capsAmount != 1);
        vm.assume(capsAmount != 3);
        vm.assume(capsAmount != 10);

        uint256 price = veggia.capsPriceByQuantity(capsAmount);
        assertEq(price, 0, "price != 0");

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_CAPS_AMOUNT.selector));
        veggia.buyCaps{value: price}(false, capsAmount);
    }

    function test_buyUnexpectedAmountOfPremiumCaps(uint256 capsAmount) public {
        vm.assume(capsAmount != 1);
        vm.assume(capsAmount != 3);
        vm.assume(capsAmount != 10);

        uint256 price = veggia.premiumCapsPriceByQuantity(capsAmount);
        assertEq(price, 0, "price != 0");

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_CAPS_AMOUNT.selector));
        veggia.buyCaps{value: price}(true, capsAmount);
    }

    function test_buyCapsWrongPrice() public {
        uint256 oneCapsPrice = veggia.capsPriceByQuantity(1);
        uint256 threeCapsPrice = veggia.capsPriceByQuantity(3);
        uint256 tenCapsPrice = veggia.capsPriceByQuantity(10);

        assertFalse(oneCapsPrice == 0, "oneCapsPrice == 0");
        assertFalse(threeCapsPrice == 0, "threeCapsPrice == 0");
        assertFalse(tenCapsPrice == 0, "tenCapsPrice == 0");

        /* ------------------------------- Test 1 caps ------------------------------ */
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_VALUE.selector));
        veggia.buyCaps{value: oneCapsPrice - 1}(false, 1);
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_VALUE.selector));
        veggia.buyCaps{value: oneCapsPrice + 1}(false, 1);
        // Successfull when value is correct
        veggia.buyCaps{value: oneCapsPrice}(false, 1);

        /* ------------------------------- Test 3 caps ------------------------------ */
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_VALUE.selector));
        veggia.buyCaps{value: threeCapsPrice - 1}(false, 3);
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_VALUE.selector));
        veggia.buyCaps{value: threeCapsPrice + 1}(false, 3);
        // Successfull when value is correct
        veggia.buyCaps{value: threeCapsPrice}(false, 3);

        /* ------------------------------- Test 10 caps ------------------------------ */
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_VALUE.selector));
        veggia.buyCaps{value: tenCapsPrice - 1}(false, 10);
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_VALUE.selector));
        veggia.buyCaps{value: tenCapsPrice + 1}(false, 10);
        // Successfull when value is correct
        veggia.buyCaps{value: tenCapsPrice}(false, 10);
    }

    function test_buyPremiumCapsWrongPrice() public {
        uint256 oneCapsPrice = veggia.premiumCapsPriceByQuantity(1);
        uint256 threeCapsPrice = veggia.premiumCapsPriceByQuantity(3);
        uint256 tenCapsPrice = veggia.premiumCapsPriceByQuantity(10);

        assertFalse(oneCapsPrice == 0, "oneCapsPrice == 0");
        assertFalse(threeCapsPrice == 0, "threeCapsPrice == 0");
        assertFalse(tenCapsPrice == 0, "tenCapsPrice == 0");

        /* ------------------------------- Test 1 caps ------------------------------ */
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_VALUE.selector));
        veggia.buyCaps{value: oneCapsPrice - 1}(true, 1);
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_VALUE.selector));
        veggia.buyCaps{value: oneCapsPrice + 1}(true, 1);
        // Successfull when value is correct
        veggia.buyCaps{value: oneCapsPrice}(true, 1);

        /* ------------------------------- Test 3 caps ------------------------------ */
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_VALUE.selector));
        veggia.buyCaps{value: threeCapsPrice - 1}(true, 3);
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_VALUE.selector));
        veggia.buyCaps{value: threeCapsPrice + 1}(true, 3);
        // Successfull when value is correct
        veggia.buyCaps{value: threeCapsPrice}(true, 3);

        /* ------------------------------- Test 10 caps ------------------------------ */
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_VALUE.selector));
        veggia.buyCaps{value: tenCapsPrice - 1}(true, 10);
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_VALUE.selector));
        veggia.buyCaps{value: tenCapsPrice + 1}(true, 10);
        // Successfull when value is correct
        veggia.buyCaps{value: tenCapsPrice}(true, 10);
    }
}
