// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {DeployHelper} from "./utils/DeployHelper.sol";

contract VeggiaERC721CapsBalanceOfTest is Test {
    VeggiaERC721 public veggia;

    function setUp() public {
        veggia = new VeggiaERC721();
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        veggia = DeployHelper.deployVeggia(address(this), address(0x1234), serverSigner, "http://localhost:4000/");
    }

    function test_capsBalanceOfShouldBeZero() public view {
        // Free caps balance is 0
        assertEq(getFreeMintBalanceOf(address(this)), 0);
        // Paid caps balance is 0
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);
        // Paid premium caps balance is 0
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0);

        // So caps balance should be 0 too
        assertEq(veggia.capsBalanceOf(address(this)), 0);
    }

    function test_capsBalanceOfShouldBeFreeMintBalance() public {
        // Free caps balance is 0
        assertEq(getFreeMintBalanceOf(address(this)), 0);

        // Wait for 1 freeMintCooldown to get a freemint caps
        vm.warp(block.timestamp + veggia.freeMintCooldown());

        // Free caps balance is 3
        assertEq(getFreeMintBalanceOf(address(this)), 3);
        // Paid caps balance is 0
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);
        // Paid premium caps balance is 0
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0);

        // So caps balance should be 1 (free + paid + paidPremium)
        assertEq(veggia.capsBalanceOf(address(this)), 3);
    }

    function test_capsBalanceOfShouldBePaidBalance() public {
        // Free caps balance is 0
        assertEq(getFreeMintBalanceOf(address(this)), 0);
        // Paid caps balance is 0
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);
        // Paid premium caps balance is 0
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0);

        // Buy 3 caps
        veggia.buyCaps{value: veggia.capsPriceByQuantity(3)}(false, 3);

        // Free caps balance still 0
        assertEq(getFreeMintBalanceOf(address(this)), 0);
        // Paid caps balance is 3
        assertEq(veggia.paidCapsBalanceOf(address(this)), 3);
        // Paid premium caps balance still 0
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0);

        // So caps balance should be 3 (free + paid + paidPremium)
        assertEq(veggia.capsBalanceOf(address(this)), 3);
    }

    function test_capsBalanceOfShouldBePaidPremiumBalance() public {
        // Free caps balance is 0
        assertEq(getFreeMintBalanceOf(address(this)), 0);
        // Paid caps balance is 0
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);
        // Paid premium caps balance is 0
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0);

        // Buy 3 caps
        veggia.buyCaps{value: veggia.premiumCapsPriceByQuantity(3)}(true, 3);

        // Free caps balance still 0
        assertEq(getFreeMintBalanceOf(address(this)), 0);
        // Paid caps balance still 0
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);
        // Paid premium caps balance is 3
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 3);

        // So caps balance should be 3 (free + paid + paidPremium)
        assertEq(veggia.capsBalanceOf(address(this)), 3);
    }

    function test_capsBalanceOfShouldBeAdditionOfAllPaidBalance() public {
        // Free caps balance is 0
        assertEq(getFreeMintBalanceOf(address(this)), 0);
        // Paid caps balance is 0
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);
        // Paid premium caps balance is 0
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0);

        // Buy 3 regular caps
        veggia.buyCaps{value: veggia.capsPriceByQuantity(3)}(false, 3);
        // Buy 3 premium caps
        veggia.buyCaps{value: veggia.premiumCapsPriceByQuantity(3)}(true, 3);

        // Free caps balance still 0
        assertEq(getFreeMintBalanceOf(address(this)), 0);
        // Paid caps balance is 3
        assertEq(veggia.paidCapsBalanceOf(address(this)), 3);
        // Paid premium caps balance is 3
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 3);

        // So caps balance should be 3 (free + paid + paidPremium)
        assertEq(veggia.capsBalanceOf(address(this)), 6);
    }

    function test_capsBalanceOfShouldBePaidBalancePlusFreeMintBalance() public {
        // Free caps balance is 0
        assertEq(getFreeMintBalanceOf(address(this)), 0);

        // Wait for 1 freeMintCooldown to get a freemint caps
        vm.warp(block.timestamp + veggia.freeMintCooldown());

        // Free caps balance is 3
        assertEq(getFreeMintBalanceOf(address(this)), 3);
        // Paid caps balance is 0
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);
        // Paid premium caps balance is 0
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0);

        // Buy 3 regular caps
        veggia.buyCaps{value: veggia.capsPriceByQuantity(3)}(false, 3);

        // Free caps balance still 3
        assertEq(getFreeMintBalanceOf(address(this)), 3);
        // Paid caps balance is 3
        assertEq(veggia.paidCapsBalanceOf(address(this)), 3);
        // Paid premium caps is 0
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0);

        // So caps balance should be 3 (free + paid + paidPremium)
        assertEq(veggia.capsBalanceOf(address(this)), 6);
    }

    function test_capsBalanceOfShouldBePaidPremiumBalancePlusFreeMintBalance() public {
        // Free caps balance is 0
        assertEq(getFreeMintBalanceOf(address(this)), 0);

        // Wait for 1 freeMintCooldown to get a freemint caps
        vm.warp(block.timestamp + veggia.freeMintCooldown());

        // Free caps balance is 3
        assertEq(getFreeMintBalanceOf(address(this)), 3);
        // Paid caps balance is 0
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);
        // Paid premium caps balance is 0
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 0);

        // Buy 3 regular caps
        veggia.buyCaps{value: veggia.premiumCapsPriceByQuantity(3)}(true, 3);

        // Free caps balance still 3
        assertEq(getFreeMintBalanceOf(address(this)), 3);
        // Paid caps balance still 0
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);
        // Paid premium caps is 3
        assertEq(veggia.paidPremiumCapsBalanceOf(address(this)), 3);

        // So caps balance should be 3 (free + paid + paidPremium)
        assertEq(veggia.capsBalanceOf(address(this)), 6);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Private function                              */
    /* -------------------------------------------------------------------------- */

    function getFreeMintBalanceOf(address account) private view returns (uint256) {
        uint256 freeCapsBalance =
            ((block.timestamp - veggia.lastMintTimestamp(account)) / veggia.freeMintCooldown()) * 3;
        return freeCapsBalance > veggia.freeMintLimit() ? veggia.freeMintLimit() : freeCapsBalance;
    }
}
