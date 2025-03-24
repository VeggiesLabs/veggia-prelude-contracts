// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {DeployHelper} from "./utils/DeployHelper.sol";
import {MockPyth} from "@pythnetwork/MockPyth.sol";
import {PythHelper} from "./utils/PythHelper.sol";

contract VeggiaERC721Mint3Test is Test, ERC721Holder {
    using PythHelper for MockPyth;

    VeggiaERC721 public veggia;
    bytes[] ethPriceUpdateData;

    MockPyth public pyth;

    function setUp() public {
        veggia = new VeggiaERC721();
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        (veggia, pyth) =
            DeployHelper.deployVeggiaWithPyth(address(this), address(1234), serverSigner, "http://localhost:4000/");

        ethPriceUpdateData = pyth.createEthUpdate(4000);

        veggia.setCapsUsdPrice(3, 0.09 ether);
        veggia.setCapsUsdPrice(9, 0.19 ether);
        veggia.setCapsUsdPrice(30, 0.49 ether);
    }

    function test_mint3() public {
        assertEq(veggia.capsBalanceOf(address(this)), 0);
        assertEq(veggia.paidCapsBalanceOf(address(this)), 0);

        uint256 threeCapsPrice = veggia.capsUsdPriceByQuantity(3) / 4000;
        veggia.buyCaps{value: threeCapsPrice + 1}(false, 3, ethPriceUpdateData);

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

        uint256 threePremiumCapsPrice = veggia.premiumCapsUsdPriceByQuantity(3) / 4000;
        veggia.buyCaps{value: threePremiumCapsPrice + 1}(true, 3, ethPriceUpdateData);

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

    receive () external payable {}
}
