// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {ERC721TransferLock} from "../src/ERC721TransferLock.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {DeployHelper} from "./utils/DeployHelper.sol";
import {MockPyth} from "@pythnetwork/MockPyth.sol";
import {PythHelper} from "./utils/PythHelper.sol";

contract VeggiaERC721TransferLockTest is Test, ERC721Holder {
    using PythHelper for MockPyth;

    VeggiaERC721 public veggia;
    MockPyth public pyth;
    bytes[] ethPriceUpdateData;

    function setUp() public {
        veggia = new VeggiaERC721();
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        (veggia, pyth) =
            DeployHelper.deployVeggiaWithPyth(address(this), address(1234), serverSigner, "http://localhost:4000/");

        DeployHelper.updateSuperPassFor(veggia, SERVER_SIGNER, address(this), true);

        veggia.setCapsUsdPrice(3, 0.09 ether);
        veggia.setCapsUsdPrice(9, 0.19 ether);
        veggia.setCapsUsdPrice(30, 0.49 ether);

        ethPriceUpdateData = pyth.createEthUpdate(4000);
    }

    /**
     * Test if only the 3rd minted token of the first free mint is locked
     */
    function test_transferFirst3Tokens() public {
        vm.warp((veggia.freeMintCooldown() * 3) / 2); // 1.5 * cooldown
        assertEq(veggia.capsBalanceOf(address(this)), 3);

        // First mint should mint 3 tokens
        vm.expectEmit(false, false, false, true);
        emit VeggiaERC721.LockedFirstMintToken(2);
        veggia.freeMint3();

        assertEq(veggia.balanceOf(address(this)), 3);

        // Transfer 1st token to another address shoul be successful
        veggia.transferFrom(address(this), address(0x1), 0);

        // Transfer 2nd token to another address shoul be successful
        veggia.transferFrom(address(this), address(0x1), 1);

        // Transfer 3rd token to another address shoul fail
        vm.expectRevert(abi.encodeWithSelector(ERC721TransferLock.TransferLocked.selector, 2));
        veggia.transferFrom(address(this), address(0x1), 2);
    }

    function test_burnLockedTokens() public {
        vm.warp((veggia.freeMintCooldown() * 3) / 2); // 1.5 * cooldown
        assertEq(veggia.capsBalanceOf(address(this)), 3);

        // First mint should mint 3 tokens
        veggia.freeMint3();

        assertEq(veggia.balanceOf(address(this)), 3);

        // Burn 1st token should be successful
        assertFalse(veggia.isTokenLocked(0));
        veggia.burn(0);

        // Burn 2nd token should be successful
        assertFalse(veggia.isTokenLocked(1));
        veggia.burn(1);

        // Burn 3rd token should be successful too
        assertTrue(veggia.isTokenLocked(2));
        veggia.burn(2);
    }

    function test_batchBurnLockedTokens() public {
        vm.warp((veggia.freeMintCooldown() * 3) / 2); // 1.5 * cooldown
        assertEq(veggia.capsBalanceOf(address(this)), 3);

        // First mint should mint 3 tokens
        veggia.freeMint3();

        assertEq(veggia.balanceOf(address(this)), 3);
        assertFalse(veggia.isTokenLocked(0));
        assertFalse(veggia.isTokenLocked(1));
        assertTrue(veggia.isTokenLocked(2));

        uint256[] memory tokenIds = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            tokenIds[i] = i;
        }

        // Burn tokens should be successful
        veggia.batchBurn(tokenIds);
    }

    /**
     * Test if only the 3rd minted token of the first free mint is locked
     */
    function test_transferFirst3PaidTokens() public {
        // Buy an egg and open it to mint 3 tokens
        veggia.buyCaps{value: veggia.capsUsdPriceByQuantity(3) / 4000 + 1}(false, 3, ethPriceUpdateData);
        veggia.mint3(false);

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
            veggia.freeMint3();

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
            veggia.buyCaps{value: veggia.capsUsdPriceByQuantity(3) / 4000 + 1}(false, 3, ethPriceUpdateData);
            veggia.mint3(false);

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
