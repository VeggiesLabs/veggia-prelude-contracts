// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {ERC721TransferLock} from "../src/ERC721TransferLock.sol";

contract VeggiaERC721FreeMintTest is Test {
    VeggiaERC721 public veggia;

    function setUp() public {
        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        veggia.initialize(
            address(this), address(this), address(vm.envAddress("SERVER_SIGNER")), "http://localhost:4000/"
        );
    }

    /**
     * Test if only the 3rd minted token of the first free mint is locked
     */
    function test_transferFirst3Tokens() public {
        vm.warp((veggia.freeMintCooldown() * 3) / 2); // 1.5 * cooldown
        assertEq(veggia.eggBalanceOf(address(this)), 1);

        // First mint should mint 3 tokens
        veggia.freeMint();

        assertEq(veggia.balanceOf(address(this)), 3);

        // Transfer 1st token to another address shoul be successful
        veggia.transferFrom(address(this), address(0x1), 0);

        // Transfer 2nd token to another address shoul be successful
        veggia.transferFrom(address(this), address(0x1), 1);

        // Transfer 3rd token to another address shoul fail
        vm.expectRevert(abi.encodeWithSelector(ERC721TransferLock.TransferLocked.selector, 2));
        veggia.transferFrom(address(this), address(0x1), 2);
    }

    /**
     * Test if only the 3rd minted token of the first free mint is locked
     */
    function test_transferFirst3PaidTokens() public {
        // Buy an egg and open it to mint 3 tokens
        veggia.buyEgg{value: veggia.eggPrice()}();
        veggia.mint();

        assertEq(veggia.balanceOf(address(this)), 3);

        // Transfer 1st token to another address shoul be successful
        veggia.transferFrom(address(this), address(0x1), 0);

        // Transfer 2nd token to another address shoul be successful
        veggia.transferFrom(address(this), address(0x1), 1);

        // Transfer 3rd token to another address shoul fail
        vm.expectRevert(abi.encodeWithSelector(ERC721TransferLock.TransferLocked.selector, 2));
        veggia.transferFrom(address(this), address(0x1), 2);
    }

    /**
     * Test if only the 3rd minted token is locked
     * @param mintAmount The amount of tokens to mint
     */
    function test_fuzz_tokenTransferLock(uint256 mintAmount) public {
        mintAmount = bound(mintAmount, 1, 100);

        for (uint256 i = 0; i < mintAmount; i += 3) {
            vm.warp(block.timestamp + (veggia.freeMintCooldown()));
            veggia.freeMint();

            veggia.transferFrom(address(this), address(0x1), i);
            veggia.transferFrom(address(this), address(0x1), i + 1);
            if (i == 0) {
                // Transfer 3rd token to another address shoul fail
                vm.expectRevert(abi.encodeWithSelector(ERC721TransferLock.TransferLocked.selector, 2));
            }
            veggia.transferFrom(address(this), address(0x1), i + 2);
        }
    }

    /**
     * Test if only the 3rd minted token is locked when minting paid tokens
     * @param mintAmount The amount of tokens to mint
     */
    function test_fuzz_tokenTransferLockPaidMint(uint256 mintAmount) public {
        mintAmount = bound(mintAmount, 1, 100);

        for (uint256 i = 0; i < mintAmount; i += 3) {
            // Buy an egg and open it to mint 3 tokens
            veggia.buyEgg{value: veggia.eggPrice()}();
            veggia.mint();

            veggia.transferFrom(address(this), address(0x1), i);
            veggia.transferFrom(address(this), address(0x1), i + 1);
            if (i == 0) {
                // Transfer 3rd token to another address shoul fail
                vm.expectRevert(abi.encodeWithSelector(ERC721TransferLock.TransferLocked.selector, 2));
            }
            veggia.transferFrom(address(this), address(0x1), i + 2);
        }
    }

    fallback() external payable {}

    receive() external payable {}
}
