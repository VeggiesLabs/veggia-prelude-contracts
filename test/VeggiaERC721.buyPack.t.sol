// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {MintHelper} from "./utils/MintHelper.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {DeployHelper} from "./utils/DeployHelper.sol";

contract VeggiaERC721buyPremiumPackTest is Test, ERC721Holder {
    using MintHelper for VeggiaERC721;

    VeggiaERC721 public veggia;

    address feeReceiver = address(0x9999);
    address user = address(0x5555);

    function setUp() public {
        veggia = new VeggiaERC721();
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        veggia = DeployHelper.deployVeggia(address(this), feeReceiver, serverSigner, "http://localhost:4000/");
    }

    function test_buyPremiumPack() public {
        uint256 price = veggia.premiumPackPrice();

        assertEq(veggia.balanceOf(address(this)), 0, "Initial token balance should be 0");
        assertEq(veggia.capsBalanceOf(address(this)), 0, "Initial caps balance should be 0");
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0, "Initial paid caps balance should be 0");
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0, "Initial paid premium caps balance should be 0");

        // Check if the CapsOpened event is emitted correctly
        // topic[1] should be the caller (indexed)
        // data should be:
        //   - 0: 0 minted token ID
        //   - 1: false (isPremium)
        //   - 2: true (isPack)
        vm.expectEmit(true, false, false, true, address(veggia));
        emit VeggiaERC721.CapsOpened(address(this), 0, false, true);
        veggia.buyPremiumPack{value: price}();

        assertEq(veggia.balanceOf(address(this)), 1, "Initial token balance should be 0");
        assertEq(veggia.capsBalanceOf(address(this)), 15, "Initial caps balance should be 0");
        assertEq(veggia.paidCapsBalanceOf(address(this)), 12, "Initial paid caps balance should be 0");
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 3, "Initial paid premium caps balance should be 0");
    }

    function test_buyPremiumPackWrongValue(uint256 price) public {
        uint256 realPrice = veggia.premiumPackPrice();
        vm.assume(price != realPrice);
        vm.deal(address(this), price);

        assertEq(veggia.balanceOf(address(this)), 0, "Initial token balance should be 0");
        assertEq(veggia.capsBalanceOf(address(this)), 0, "Initial caps balance should be 0");
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0, "Initial paid caps balance should be 0");
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0, "Initial paid premium caps balance should be 0");

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.WRONG_VALUE.selector));
        veggia.buyPremiumPack{value: price}();

        assertEq(veggia.balanceOf(address(this)), 0, "Initial token balance should be 0");
        assertEq(veggia.capsBalanceOf(address(this)), 0, "Initial caps balance should be 0");
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0, "Initial paid caps balance should be 0");
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0, "Initial paid premium caps balance should be 0");
    }
}
