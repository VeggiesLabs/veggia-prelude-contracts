// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";

contract VeggiaERC721ERC2981Test is Test {
    VeggiaERC721 public veggia;

    function setUp() public {
        veggia = new VeggiaERC721(address(msg.sender), "http://localhost:4000/");
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        veggia.initialize(address(this), address(0x1234), serverSigner, "http://localhost:4000/");
    }

    function test_initialRoyaltiesValues() public view {
        (address receiver, uint256 amount) = veggia.royaltyInfo(0, 1 ether);

        assertEq(receiver, address(0x1234));
        assertEq(amount, 0);
    }

    function test_supportsInterface() public view {
        assertTrue(veggia.supportsInterface(type(IERC2981).interfaceId));
    }
}
