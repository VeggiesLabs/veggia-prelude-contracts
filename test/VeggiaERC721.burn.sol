// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";

contract VeggiaERC721BurnTest is Test {
    VeggiaERC721 public veggia;

    function setUp() public {
        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        veggia.initialize(address(this), address(this), serverSigner, "http://localhost:4000/");
    }

    function test_burn() public {
        vm.warp((veggia.freeMintCooldown() * 3) / 2); // 1.5 * cooldown
        veggia.freeMint();

        veggia.burn(0);
    }

    function test_batchBurn() public {
        vm.warp(veggia.freeMintCooldown()); // 1.5 * cooldown
        veggia.freeMint();
        vm.warp(veggia.freeMintCooldown() * 2); // 1.5 * cooldown
        veggia.freeMint();
        vm.warp(veggia.freeMintCooldown() * 3); // 1.5 * cooldown
        veggia.freeMint();
        vm.warp(veggia.freeMintCooldown() * 4); // 1.5 * cooldown
        veggia.freeMint();

        uint256[] memory tokenIds = new uint256[](11);
        for (uint256 i = 0; i < 11; i++) {
            if (i < 2) {
                tokenIds[i] = i;
            } else {
                tokenIds[i] = i + 1;
            }
        }

        veggia.batchBurn(tokenIds);
    }
}
