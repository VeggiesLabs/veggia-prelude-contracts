// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {MintHelper} from "./utils/MintHelper.sol";

contract VeggiaERC721OnlyOwnerFctTest is Test {
    using MintHelper for VeggiaERC721;

    VeggiaERC721 public veggia;
    address owner = address(0x1234123412341234123412341234123412341234);

    function setUp() public {
        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        veggia.initialize(owner, address(0x1234), serverSigner, "http://localhost:4000/");

        assertEq(veggia.owner(), owner);

        vm.deal(owner, 1000 ether);
    }

    function test_setBaseURI() public {
        veggia.forceMint3(owner, 1);
        assertEq(veggia.tokenURI(0), "http://localhost:4000/0");

        vm.expectEmit(false, false, false, true);
        emit VeggiaERC721.BaseURIChanged("http://new-url.io/");
        vm.prank(owner);
        veggia.setBaseURI("http://new-url.io/");

        assertEq(veggia.tokenURI(0), "http://new-url.io/0");
    }

    function test_setCapsPrice() public {
        assertEq(veggia.capsPriceByQuantity(1000), 0);

        vm.expectEmit(true, false, false, true);
        emit VeggiaERC721.CapsPriceChanged(1000, 1 ether);
        vm.prank(owner);
        veggia.setCapsPrice(1000, 1 ether);

        assertEq(veggia.capsPriceByQuantity(1000), 1 ether);
    }

    function test_setPremiumCapsPrice() public {
        assertEq(veggia.premiumCapsPriceByQuantity(1000), 0);

        vm.expectEmit(true, false, false, true);
        emit VeggiaERC721.PremiumCapsPriceChanged(1000, 1 ether);
        vm.prank(owner);
        veggia.setPremiumCapsPrice(1000, 1 ether);

        assertEq(veggia.premiumCapsPriceByQuantity(1000), 1 ether);
    }

    function test_setPremiumPackPrice() public {
        assertEq(veggia.premiumPackPrice(), 0.0036 ether);

        vm.expectEmit(false, false, false, true);
        emit VeggiaERC721.PremiumPackPriceChanged(1 ether);
        vm.prank(owner);
        veggia.setPremiumPackPrice(1 ether);

        assertEq(veggia.premiumPackPrice(), 1 ether);
    }

    function test_setFreeMintLimit(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max / 3 - 1);

        assertEq(veggia.freeMintLimit(), 6);

        vm.expectEmit(false, false, false, true);
        emit VeggiaERC721.FreeMintLimitChanged(3 * amount);
        vm.prank(owner);
        veggia.setFreeMintLimit(3 * amount);

        assertEq(veggia.freeMintLimit(), 3 * amount);
    }

    function test_setFreeMintLimitNotModulo3(uint256 amount) public {
        vm.assume(amount % 3 != 0);

        assertEq(veggia.freeMintLimit(), 6);

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.FREE_MINT_LIMIT_MUST_BE_MULTIPLE_OF_3.selector));
        vm.prank(owner);
        veggia.setFreeMintLimit(amount);

        assertEq(veggia.freeMintLimit(), 6);
    }

    function test_setFreeMintCooldown() public {
        assertEq(veggia.freeMintCooldown(), 12 hours);

        vm.expectEmit(false, false, false, true);
        emit VeggiaERC721.FreeMintCooldownChanged(3 hours);
        vm.prank(owner);
        veggia.setFreeMintCooldown(3 hours);

        assertEq(veggia.freeMintCooldown(), 3 hours);
    }

    function test_setFeeReceiver() public {
        assertEq(veggia.feeReceiver(), address(0x1234));

        vm.expectEmit(false, false, false, true);
        emit VeggiaERC721.FeeReceiverChanged(address(0x5678));
        vm.prank(owner);
        veggia.setFeeReceiver(address(0x5678));

        assertEq(veggia.feeReceiver(), address(0x5678));
    }

    function test_setCapsSigner() public {
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        assertEq(veggia.capsSigner(), serverSigner);

        vm.expectEmit(false, false, false, true);
        emit VeggiaERC721.CapsSignerChanged(address(0x77778888));
        vm.prank(owner);
        veggia.setCapsSigner(address(0x77778888));

        assertEq(veggia.capsSigner(), address(0x77778888));
    }

    function test_setDefaultRoyalty() public {
        (address receiver, uint256 amount) = veggia.royaltyInfo(0, 1 ether);

        assertEq(receiver, address(0x1234));
        assertEq(amount, 0);

        vm.expectEmit(false, false, false, true);
        emit VeggiaERC721.DefaultRoyaltyChanged(address(0x9999), 1000);
        vm.prank(owner);
        veggia.setDefaultRoyalty(address(0x9999), 1000);

        (receiver, amount) = veggia.royaltyInfo(0, 1 ether);

        assertEq(receiver, address(0x9999));
        assertEq(amount, 1 ether * 1000 / 10000);
    }
}
