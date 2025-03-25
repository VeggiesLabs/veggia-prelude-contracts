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

contract VeggiaERC721SuperPassTest is Test, ERC721Holder {
    using PythHelper for MockPyth;

    VeggiaERC721 public veggia;
    MockPyth public pyth;
    bytes[] ethPriceUpdateData;

    function setUp() public {
        veggia = new VeggiaERC721();
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        (veggia, pyth) =
            DeployHelper.deployVeggiaWithPyth(address(this), address(1234), serverSigner, "http://localhost:4000/");

        ethPriceUpdateData = pyth.createEthUpdate(4000);
    }

    function test_transferWithPass(address owner) public {
        vm.assume(owner != address(0));
        vm.assume(owner.code.length == 0);

        vm.warp(veggia.freeMintCooldown() * 2);

        vm.startPrank(owner);
        veggia.freeMint3();

        assertEq(veggia.balanceOf(owner), 3);
        assertEq(veggia.ownerOf(0), owner);
        assertEq(veggia.ownerOf(1), owner);
        assertEq(veggia.ownerOf(2), owner);

        DeployHelper.updateSuperPassFor(veggia, SERVER_SIGNER, owner, true);

        // TransferFrom token 0 should succeed
        veggia.transferFrom(owner, address(0x1), 0);
        // SafeTransferFrom token 1 should succeed too
        veggia.safeTransferFrom(owner, address(0x1), 1);

        // re-lock transfer
        DeployHelper.updateSuperPassFor(veggia, SERVER_SIGNER, owner, false);

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.CANT_TRANSFER_WITHOUT_SUPER_PASS.selector, owner, 2));
        veggia.transferFrom(owner, address(0x1), 2);

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.CANT_TRANSFER_WITHOUT_SUPER_PASS.selector, owner, 2));
        veggia.safeTransferFrom(owner, address(0x1), 2);
    }

    function test_approveWithPass(address owner, address spender) public {
        vm.assume(owner != address(0));
        vm.assume(spender != address(0));
        vm.assume(owner != spender);
        vm.assume(spender.code.length == 0);
        vm.assume(owner.code.length == 0);

        vm.warp(veggia.freeMintCooldown() * 2);

        vm.startPrank(owner);
        veggia.freeMint3();

        assertEq(veggia.balanceOf(owner), 3);
        assertEq(veggia.ownerOf(0), owner);
        assertEq(veggia.ownerOf(1), owner);

        DeployHelper.updateSuperPassFor(veggia, SERVER_SIGNER, owner, true);

        // Approve token 0 should succeed
        veggia.approve(owner, 0);
        // Approve all token should succeed too
        veggia.setApprovalForAll(spender, true);

        // Spender can transfer token 0
        veggia.transferFrom(owner, spender, 0);

        // re-lock transfer
        DeployHelper.updateSuperPassFor(veggia, SERVER_SIGNER, owner, false);

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.CANT_APPROVE_WITHOUT_SUPER_PASS.selector));
        veggia.approve(owner, 0);

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.CANT_APPROVE_WITHOUT_SUPER_PASS.selector));
        veggia.setApprovalForAll(spender, true);

        // Spender can't transfer token 1
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.CANT_TRANSFER_WITHOUT_SUPER_PASS.selector, owner, 1));
        veggia.transferFrom(owner, spender, 1);
    }

    function test_cantTransferWithoutPass(address from) public {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        vm.warp(veggia.freeMintCooldown() * 2);

        vm.startPrank(from);
        veggia.freeMint3();

        assertEq(veggia.balanceOf(from), 3);
        assertEq(veggia.ownerOf(0), from);

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.CANT_TRANSFER_WITHOUT_SUPER_PASS.selector, from, 0));
        veggia.transferFrom(from, address(0x1), 0);

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.CANT_TRANSFER_WITHOUT_SUPER_PASS.selector, from, 0));
        veggia.safeTransferFrom(from, address(0x1), 0);
    }

    function test_cantApproveWithoutPass(address owner, address spender) public {
        vm.assume(owner != address(0));
        vm.assume(spender != address(0));
        vm.assume(owner != spender);
        vm.assume(spender.code.length == 0);
        vm.assume(owner.code.length == 0);

        vm.warp(veggia.freeMintCooldown() * 2);

        vm.startPrank(owner);
        veggia.freeMint3();

        assertEq(veggia.balanceOf(owner), 3);
        assertEq(veggia.ownerOf(0), owner);

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.CANT_APPROVE_WITHOUT_SUPER_PASS.selector));
        veggia.approve(owner, 0);

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721.CANT_APPROVE_WITHOUT_SUPER_PASS.selector));
        veggia.setApprovalForAll(spender, true);
    }
}
