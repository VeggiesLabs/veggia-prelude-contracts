// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";

contract VeggiaERC721FreeMintTest is Test {
    VeggiaERC721 public veggia;

    function setUp() public {
        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        veggia.initialize(address(this), address(this), serverSigner, "http://localhost:4000/");
    }

    function test_freeMintWhenNoMintIsAvailable() public {
        vm.warp(0);
        assertEq(veggia.capsBalanceOf(address(this)), 0);

        uint256 balanceBefore = veggia.balanceOf(address(this));

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INSUFFICIENT_CAPS_BALANCE.selector));
        veggia.freeMint();

        uint256 balanceAfter = veggia.balanceOf(address(this));

        assertEq(balanceAfter, balanceBefore);
        assertEq(veggia.capsBalanceOf(address(this)), 0);
    }

    function test_freeMintWhenOneMintIsAvailable() public {
        vm.warp((veggia.freeMintCooldown() * 3) / 2); // 1.5 * cooldown
        assertEq(veggia.capsBalanceOf(address(this)), 1);

        uint256 balanceBefore = veggia.balanceOf(address(this));

        // First mint should succeed
        veggia.freeMint();

        // Second mint should fail
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INSUFFICIENT_CAPS_BALANCE.selector));
        veggia.freeMint();

        uint256 balanceAfter = veggia.balanceOf(address(this));

        assertTrue(balanceAfter - balanceBefore == 3);
        assertEq(veggia.capsBalanceOf(address(this)), 0);

        // Go to the second mint cooldown
        vm.warp(veggia.freeMintCooldown() * 2); // 2 * cooldown
        assertEq(veggia.capsBalanceOf(address(this)), 1);

        // First mint should succeed
        veggia.freeMint();

        // Second mint should fail
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INSUFFICIENT_CAPS_BALANCE.selector));
        veggia.freeMint();

        balanceAfter = veggia.balanceOf(address(this));

        assertTrue(balanceAfter - balanceBefore == 6);
        assertEq(veggia.capsBalanceOf(address(this)), 0);
    }

    function test_freeMintWhenTwoMintAreAvailable() public {
        vm.warp(veggia.freeMintCooldown() * 2); // 2 * cooldown
        assertEq(veggia.capsBalanceOf(address(this)), 2);

        uint256 balanceBefore = veggia.balanceOf(address(this));

        // First mint should succeed
        veggia.freeMint();
        // Second mint should succeed
        veggia.freeMint();

        // Third mint should fail
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INSUFFICIENT_CAPS_BALANCE.selector));
        veggia.freeMint();

        uint256 balanceAfter = veggia.balanceOf(address(this));

        assertEq(balanceAfter - balanceBefore, 6);
        assertEq(veggia.capsBalanceOf(address(this)), 0);
    }

    function test_freeMintWhenMoreThanTwoMintAreAvailable() public {
        vm.warp(veggia.freeMintCooldown() * 1000); // 1000 * cooldown
        assertEq(veggia.capsBalanceOf(address(this)), 2);

        uint256 balanceBefore = veggia.balanceOf(address(this));

        // First mint should succeed
        veggia.freeMint();
        // Second mint should succeed
        veggia.freeMint();

        // Third mint should fail
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INSUFFICIENT_CAPS_BALANCE.selector));
        veggia.freeMint();

        uint256 balanceAfter = veggia.balanceOf(address(this));

        assertTrue(balanceAfter - balanceBefore == 6);
        assertEq(veggia.capsBalanceOf(address(this)), 0);
    }

    function test_invariant_freeMint(uint256 randomTimestamp) public {
        randomTimestamp = bound(randomTimestamp, 0 + veggia.freeMintCooldown(), 2 days);
        vm.warp(randomTimestamp);

        uint256 balanceBefore = veggia.balanceOf(address(this));

        bool failed = false;
        while (!failed) {
            try veggia.freeMint() {}
            catch {
                failed = true;
            }
        }

        uint256 balanceAfter = veggia.balanceOf(address(this));

        // Freemint limit is 2
        assertTrue(
            randomTimestamp < veggia.freeMintCooldown()
                ? balanceAfter - balanceBefore == 0
                : randomTimestamp < veggia.freeMintCooldown() * 2
                    ? balanceAfter - balanceBefore == 3
                    : balanceAfter - balanceBefore == 6
        );
        assertEq(veggia.capsBalanceOf(address(this)), 0);
    }
}
