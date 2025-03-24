// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {MintHelper} from "./utils/MintHelper.sol";
import {PythHelper} from "./utils/PythHelper.sol";
import {DeployHelper} from "./utils/DeployHelper.sol";
import {MockPyth} from "@pythnetwork/MockPyth.sol";

contract VeggiaERC721BuyCapsTest is Test {
    using MintHelper for VeggiaERC721;
    using PythHelper for MockPyth;

    VeggiaERC721 public veggia;
    MockPyth public pyth;

    address feeReceiver = address(0x9999);
    address user = address(0x5555);

    bytes[] ethPriceUpdateData;

    function setUp() public {
        veggia = new VeggiaERC721();
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        (veggia, pyth) =
            DeployHelper.deployVeggiaWithPyth(address(this), feeReceiver, serverSigner, "http://localhost:4000/");

        ethPriceUpdateData = pyth.createEthUpdate(4000);

        veggia.setCapsUsdPrice(3, 0.09 ether);
        veggia.setCapsUsdPrice(9, 0.19 ether);
        veggia.setCapsUsdPrice(30, 0.49 ether);

        // Ensure that the caps prices are initialized
        assertTrue(veggia.capsUsdPriceByQuantity(3) != 0);
        assertTrue(veggia.capsUsdPriceByQuantity(9) != 0);
        assertTrue(veggia.capsUsdPriceByQuantity(30) != 0);
        assertTrue(veggia.premiumCapsUsdPriceByQuantity(3) != 0);
        assertTrue(veggia.premiumCapsUsdPriceByQuantity(9) != 0);
        assertTrue(veggia.premiumCapsUsdPriceByQuantity(30) != 0);
    }

    function test_buyThreeCaps() public {
        uint256 feeReceiverBalanceBefore = feeReceiver.balance;
        uint256 threeCapsPrice = veggia.capsUsdPriceByQuantity(3) / 4000;
        assertEq(veggia.capsBalanceOf(user), 0, "capsBalanceOf != 0");
        assertEq(veggia.paidCapsBalanceOf(user), 0, "paidCapsBalanceOf != 0");

        vm.deal(user, threeCapsPrice + 1); // +1 to pay pyth fee
        vm.prank(user);
        veggia.buyCaps{value: threeCapsPrice + 1}(false, 3, ethPriceUpdateData); // +1 to pay pyth fee

        assertEq(veggia.capsBalanceOf(user), 3, "capsBalanceOf != 3");
        assertEq(veggia.paidCapsBalanceOf(user), 3, "paidCapsBalanceOf != 3");
        assertEq(
            feeReceiver.balance,
            feeReceiverBalanceBefore + threeCapsPrice,
            "balance != feeReceiverBalanceBefore + threeCapsPrice"
        );
    }

    function test_buyNineCaps() public {
        uint256 feeReceiverBalanceBefore = feeReceiver.balance;
        uint256 nineCapsPrice = veggia.capsUsdPriceByQuantity(9) / 4000;
        assertEq(veggia.capsBalanceOf(user), 0, "capsBalanceOf != 0");
        assertEq(veggia.paidCapsBalanceOf(user), 0, "paidCapsBalanceOf != 0");

        vm.deal(user, nineCapsPrice + 1); // +1 to pay pyth fee
        vm.prank(user);
        veggia.buyCaps{value: nineCapsPrice + 1}(false, 9, ethPriceUpdateData); // +1 to pay pyth fee

        assertEq(veggia.capsBalanceOf(user), 9, "capsBalanceOf != 9");
        assertEq(veggia.paidCapsBalanceOf(user), 9, "paidCapsBalanceOf != 9");
        assertEq(
            feeReceiver.balance,
            feeReceiverBalanceBefore + nineCapsPrice,
            "balance != feeReceiverBalanceBefore + nineCapsPrice"
        );
    }

    function test_buyThirtyCaps() public {
        uint256 feeReceiverBalanceBefore = feeReceiver.balance;
        uint256 thirtyCapsPrice = veggia.capsUsdPriceByQuantity(30) / 4000;
        assertEq(veggia.capsBalanceOf(user), 0, "capsBalanceOf != 0");
        assertEq(veggia.paidCapsBalanceOf(user), 0, "paidCapsBalanceOf != 0");

        vm.deal(user, thirtyCapsPrice + 1); // +1 to pay pyth fee
        vm.prank(user);
        veggia.buyCaps{value: thirtyCapsPrice + 1}(false, 30, ethPriceUpdateData); // +1 to pay pyth fee

        assertEq(veggia.capsBalanceOf(user), 30, "capsBalanceOf != 30");
        assertEq(veggia.paidCapsBalanceOf(user), 30, "paidCapsBalanceOf != 30");
        assertEq(
            feeReceiver.balance,
            feeReceiverBalanceBefore + thirtyCapsPrice,
            "balance != feeReceiverBalanceBefore + thirtyCapsPrice"
        );
    }

    function test_buyThreePremiumCaps() public {
        uint256 feeReceiverBalanceBefore = feeReceiver.balance;
        uint256 onePremiumCapsPrice = veggia.premiumCapsUsdPriceByQuantity(3) / 4000;
        assertEq(veggia.capsBalanceOf(user), 0, "capsBalanceOf != 0");
        assertEq(veggia.paidPremiumCapsBalanceOf(user), 0, "paidPremiumCapsBalanceOf != 0");

        vm.deal(user, onePremiumCapsPrice + 1); // +1 to pay pyth fee
        vm.prank(user);
        veggia.buyCaps{value: onePremiumCapsPrice + 1}(true, 3, ethPriceUpdateData); // +1 to pay pyth fee

        assertEq(veggia.capsBalanceOf(user), 3, "capsBalanceOf != 3");
        assertEq(veggia.paidPremiumCapsBalanceOf(user), 3, "paidPremiumCapsBalanceOf != 3");
        assertEq(
            feeReceiver.balance,
            feeReceiverBalanceBefore + onePremiumCapsPrice,
            "balance != feeReceiverBalanceBefore + onePremiumCapsPrice"
        );
    }

    function test_buyNinePremiumCaps() public {
        uint256 feeReceiverBalanceBefore = feeReceiver.balance;
        uint256 threePremiumCapsPrice = veggia.premiumCapsUsdPriceByQuantity(9) / 4000;
        assertEq(veggia.capsBalanceOf(user), 0, "capsBalanceOf != 0");
        assertEq(veggia.paidPremiumCapsBalanceOf(user), 0, "paidPremiumCapsBalanceOf != 0");

        vm.deal(user, threePremiumCapsPrice + 1); // +1 to pay pyth fee
        vm.prank(user);
        veggia.buyCaps{value: threePremiumCapsPrice + 1}(true, 9, ethPriceUpdateData); // +1 to pay pyth fee

        assertEq(veggia.capsBalanceOf(user), 9, "capsBalanceOf != 9");
        assertEq(veggia.paidPremiumCapsBalanceOf(user), 9, "paidPremiumCapsBalanceOf != 9");
        assertEq(
            feeReceiver.balance,
            feeReceiverBalanceBefore + threePremiumCapsPrice,
            "balance != feeReceiverBalanceBefore + threePremiumCapsPrice"
        );
    }

    function test_buyTenPremiumCaps() public {
        uint256 feeReceiverBalanceBefore = feeReceiver.balance;
        uint256 tenPremiumCapsPrice = veggia.premiumCapsUsdPriceByQuantity(30) / 4000;
        assertEq(veggia.capsBalanceOf(user), 0, "capsBalanceOf != 0");
        assertEq(veggia.paidPremiumCapsBalanceOf(user), 0, "paidPremiumCapsBalanceOf != 0");

        vm.deal(user, tenPremiumCapsPrice + 1); // +1 to pay pyth fee
        vm.prank(user);
        veggia.buyCaps{value: tenPremiumCapsPrice + 1}(true, 30, ethPriceUpdateData); // +1 to pay pyth fee

        assertEq(veggia.capsBalanceOf(user), 30, "capsBalanceOf != 30");
        assertEq(veggia.paidPremiumCapsBalanceOf(user), 30, "paidPremiumCapsBalanceOf != 30");
        assertEq(
            feeReceiver.balance,
            feeReceiverBalanceBefore + tenPremiumCapsPrice,
            "balance != feeReceiverBalanceBefore + tenPremiumCapsPrice"
        );
    }

    function test_buyUnexpectedAmountOfCapsModule3(uint256 capsAmount) public {
        vm.assume(capsAmount != 3);
        vm.assume(capsAmount != 9);
        vm.assume(capsAmount != 30);
        vm.assume(capsAmount % 3 == 0);

        uint256 price = veggia.capsUsdPriceByQuantity(capsAmount) / 4000;
        assertEq(price, 0, "price != 0");

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.UNKNOWN_CAPS_PRICE_FOR.selector, capsAmount, false));
        veggia.buyCaps{value: price}(false, capsAmount, ethPriceUpdateData);
    }

    function test_buyUnexpectedAmountOfCapsNotModulo3(uint256 capsAmount) public {
        vm.assume(capsAmount != 3);
        vm.assume(capsAmount != 9);
        vm.assume(capsAmount != 30);
        vm.assume(capsAmount % 3 != 0);

        uint256 price = veggia.capsUsdPriceByQuantity(capsAmount) / 4000;
        assertEq(price, 0, "price != 0");

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_CAPS_QUANTITY.selector));
        veggia.buyCaps{value: price}(false, capsAmount, ethPriceUpdateData);
    }

    function test_buyUnexpectedAmountOfPremiumCapsModulo3(uint256 capsAmount) public {
        vm.assume(capsAmount != 3);
        vm.assume(capsAmount != 9);
        vm.assume(capsAmount != 30);
        vm.assume(capsAmount % 3 == 0);

        uint256 price = veggia.premiumCapsUsdPriceByQuantity(capsAmount) / 4000;
        assertEq(price, 0, "price != 0");

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.UNKNOWN_CAPS_PRICE_FOR.selector, capsAmount, true));
        veggia.buyCaps{value: price}(true, capsAmount, ethPriceUpdateData);
    }

    function test_buyUnexpectedAmountOfPremiumCapsNotModulo3(uint256 capsAmount) public {
        vm.assume(capsAmount != 3);
        vm.assume(capsAmount != 9);
        vm.assume(capsAmount != 30);
        vm.assume(capsAmount % 3 != 0);

        uint256 price = veggia.premiumCapsUsdPriceByQuantity(capsAmount) / 4000;
        assertEq(price, 0, "price != 0");

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_CAPS_QUANTITY.selector));
        veggia.buyCaps{value: price}(true, capsAmount, ethPriceUpdateData);
    }

    function test_buyCapsWrongPrice() public {
        uint256 threeCapsPrice = veggia.capsUsdPriceByQuantity(3) / 4000;
        uint256 nineCapsPrice = veggia.capsUsdPriceByQuantity(9) / 4000;
        uint256 thirtyCapsPrice = veggia.capsUsdPriceByQuantity(30) / 4000;

        assertFalse(threeCapsPrice == 0, "threeCapsPrice == 0");
        assertFalse(nineCapsPrice == 0, "nineCapsPrice == 0");
        assertFalse(thirtyCapsPrice == 0, "thirtyCapsPrice == 0");

        /* ------------------------------- Test 1 caps ------------------------------ */
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.NOT_ENOUGH_VALUE.selector));
        veggia.buyCaps{value: threeCapsPrice - 1}(false, 3, ethPriceUpdateData);
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.NOT_ENOUGH_VALUE.selector));
        veggia.buyCaps{value: threeCapsPrice}(false, 3, ethPriceUpdateData);

        /* ------------------------------- Test 3 caps ------------------------------ */
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.NOT_ENOUGH_VALUE.selector));
        veggia.buyCaps{value: nineCapsPrice - 1}(false, 9, ethPriceUpdateData);
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.NOT_ENOUGH_VALUE.selector));
        veggia.buyCaps{value: nineCapsPrice}(false, 9, ethPriceUpdateData);

        /* ------------------------------- Test 10 caps ------------------------------ */
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.NOT_ENOUGH_VALUE.selector));
        veggia.buyCaps{value: thirtyCapsPrice - 1}(false, 30, ethPriceUpdateData);
        // Successfull when value is correc
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.NOT_ENOUGH_VALUE.selector));
        veggia.buyCaps{value: thirtyCapsPrice}(false, 30, ethPriceUpdateData);
    }

    function test_buyPremiumCapsWrongPrice() public {
        uint256 threeCapsPrice = veggia.premiumCapsUsdPriceByQuantity(3) / 4000;
        uint256 nineCapsPrice = veggia.premiumCapsUsdPriceByQuantity(9) / 4000;
        uint256 thirtyCapsPrice = veggia.premiumCapsUsdPriceByQuantity(30) / 4000;

        assertFalse(threeCapsPrice == 0, "threeCapsPrice == 0");
        assertFalse(nineCapsPrice == 0, "nineCapsPrice == 0");
        assertFalse(thirtyCapsPrice == 0, "thirtyCapsPrice == 0");

        /* ------------------------------- Test 1 caps ------------------------------ */
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.NOT_ENOUGH_VALUE.selector));
        veggia.buyCaps{value: threeCapsPrice - 1}(true, 3, ethPriceUpdateData);
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.NOT_ENOUGH_VALUE.selector));
        veggia.buyCaps{value: threeCapsPrice}(true, 3, ethPriceUpdateData);

        /* ------------------------------- Test 3 caps ------------------------------ */
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.NOT_ENOUGH_VALUE.selector));
        veggia.buyCaps{value: nineCapsPrice - 1}(true, 9, ethPriceUpdateData);
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.NOT_ENOUGH_VALUE.selector));
        veggia.buyCaps{value: nineCapsPrice}(true, 9, ethPriceUpdateData);

        /* ------------------------------- Test 10 caps ------------------------------ */
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.NOT_ENOUGH_VALUE.selector));
        veggia.buyCaps{value: thirtyCapsPrice - 1}(true, 30, ethPriceUpdateData);
        // Successfull when value is correc
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.NOT_ENOUGH_VALUE.selector));
        veggia.buyCaps{value: thirtyCapsPrice}(true, 30, ethPriceUpdateData);
    }

    receive() external payable {}
}
