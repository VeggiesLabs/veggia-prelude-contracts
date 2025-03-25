// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {DeployHelper} from "./utils/DeployHelper.sol";
import {MintHelper} from "./utils/MintHelper.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract VeggiaERC721BurnTest is Test, ERC721Holder {
    using MintHelper for VeggiaERC721;

    VeggiaERC721 public veggia;

    function setUp() public {
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        veggia = DeployHelper.deployVeggia(address(this), address(this), serverSigner, "http://localhost:4000/");
        DeployHelper.unlockSuperPassFor(veggia, SERVER_SIGNER, address(this));
    }

    function test_burn() public {
        assertEq(veggia.balanceOf(address(this)), 0);
        veggia.forceMint3(address(this), 1);
        assertEq(veggia.balanceOf(address(this)), 3);

        assertEq(veggia.ownerOf(0), address(this));

        veggia.burn(0);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
        veggia.ownerOf(0);
    }

    function test_batchBurn() public {
        assertEq(veggia.balanceOf(address(this)), 0);
        veggia.forceMint3(address(this), 4);
        assertEq(veggia.balanceOf(address(this)), 4 * 3);

        assertEq(veggia.ownerOf(0), address(this));
        assertEq(veggia.ownerOf(1), address(this));
        assertEq(veggia.ownerOf(2), address(this));
        assertEq(veggia.ownerOf(3), address(this));
        assertEq(veggia.ownerOf(4), address(this));
        assertEq(veggia.ownerOf(5), address(this));
        assertEq(veggia.ownerOf(6), address(this));
        assertEq(veggia.ownerOf(7), address(this));
        assertEq(veggia.ownerOf(8), address(this));
        assertEq(veggia.ownerOf(9), address(this));
        assertEq(veggia.ownerOf(10), address(this));
        assertEq(veggia.ownerOf(11), address(this));

        uint256[] memory tokenIds = new uint256[](6);
        tokenIds[0] = 1;
        tokenIds[1] = 9;
        tokenIds[2] = 0;
        tokenIds[3] = 4;
        tokenIds[4] = 11;
        tokenIds[5] = 7;

        veggia.batchBurn(tokenIds);

        assertEq(veggia.ownerOf(2), address(this));
        assertEq(veggia.ownerOf(3), address(this));
        assertEq(veggia.ownerOf(5), address(this));
        assertEq(veggia.ownerOf(6), address(this));
        assertEq(veggia.ownerOf(8), address(this));
        assertEq(veggia.ownerOf(10), address(this));

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
        veggia.ownerOf(0);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));
        veggia.ownerOf(1);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 4));
        veggia.ownerOf(4);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 7));
        veggia.ownerOf(7);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 9));
        veggia.ownerOf(9);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 11));
        veggia.ownerOf(11);
    }
}
