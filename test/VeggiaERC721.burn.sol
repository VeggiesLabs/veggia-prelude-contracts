// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {MintHelper} from "./utils/MintHelper.sol";

contract VeggiaERC721BurnTest is Test {
    using MintHelper for VeggiaERC721;

    VeggiaERC721 public veggia;

    function setUp() public {
        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        veggia.initialize(address(this), address(this), serverSigner, "http://localhost:4000/");
    }

    function test_burn() public {
        veggia.forceMint(address(this), 1);
        veggia.burn(0);
    }

    function test_batchBurn() public {
        veggia.forceMint(address(this), 4);

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
