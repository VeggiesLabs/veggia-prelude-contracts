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
    }

    function test_freeMintWhenNoMintIsAvailable() public {
        vm.warp(0);
        assertEq(veggia.eggBalanceOf(address(this)), 0);

        uint256 balanceBefore = veggia.balanceOf(address(this));

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INSUFFICIENT_EGG_BALANCE.selector));
        veggia.freeMint();

        uint256 balanceAfter = veggia.balanceOf(address(this));

        assertEq(balanceAfter, balanceBefore);
        assertEq(veggia.eggBalanceOf(address(this)), 0);
    }

    function test_freeMintWhenOneMintIsAvailable() public {
        vm.warp((veggia.freeMintCooldown() * 3) / 2); // 1.5 * cooldown
        assertEq(veggia.eggBalanceOf(address(this)), 1);

        uint256 balanceBefore = veggia.balanceOf(address(this));

        // First mint should succeed
        veggia.freeMint();

        // Second mint should fail
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INSUFFICIENT_EGG_BALANCE.selector));
        veggia.freeMint();

        uint256 balanceAfter = veggia.balanceOf(address(this));

        assertTrue(balanceAfter - balanceBefore == 3);
        assertEq(veggia.eggBalanceOf(address(this)), 0);

        // Go to the second mint cooldown
        vm.warp(veggia.freeMintCooldown() * 2); // 2 * cooldown
        assertEq(veggia.eggBalanceOf(address(this)), 1);

        // First mint should succeed
        veggia.freeMint();

        // Second mint should fail
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INSUFFICIENT_EGG_BALANCE.selector));
        veggia.freeMint();

        balanceAfter = veggia.balanceOf(address(this));

        assertTrue(balanceAfter - balanceBefore == 6);
        assertEq(veggia.eggBalanceOf(address(this)), 0);
    }

    function test_freeMintWhenTwoMintIsAvailable() public {
        vm.warp(veggia.freeMintCooldown() * 2); // 2 * cooldown
        assertEq(veggia.eggBalanceOf(address(this)), 2);

        uint256 balanceBefore = veggia.balanceOf(address(this));

        // First mint should succeed
        veggia.freeMint();
        // Second mint should succeed
        veggia.freeMint();

        // Third mint should fail
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INSUFFICIENT_EGG_BALANCE.selector));
        veggia.freeMint();

        uint256 balanceAfter = veggia.balanceOf(address(this));

        assertEq(balanceAfter - balanceBefore, 6);
        assertEq(veggia.eggBalanceOf(address(this)), 0);
    }

    function test_freeMintWhenMoreThanTwoMintIsAvailable() public {
        vm.warp(veggia.freeMintCooldown() * 1000); // 1000 * cooldown
        assertEq(veggia.eggBalanceOf(address(this)), 2);

        uint256 balanceBefore = veggia.balanceOf(address(this));

        // First mint should succeed
        veggia.freeMint();
        // Second mint should succeed
        veggia.freeMint();

        // Third mint should fail
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.INSUFFICIENT_EGG_BALANCE.selector));
        veggia.freeMint();

        uint256 balanceAfter = veggia.balanceOf(address(this));

        assertTrue(balanceAfter - balanceBefore == 6);
        assertEq(veggia.eggBalanceOf(address(this)), 0);
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

        assertTrue(balanceAfter - balanceBefore <= veggia.freeMintLimit() * 3);
        assertEq(veggia.eggBalanceOf(address(this)), 0);
    }
}
