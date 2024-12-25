// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {VeggiaERC721Proxy} from "../src/proxy/VeggiaERC721Proxy.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract VeggiaERC721FreeMintTest is Test {
    VeggiaERC721Proxy public proxy;
    VeggiaERC721 public veggia;

    function setUp() public {
        veggia = new VeggiaERC721(
            address(msg.sender),
            "http://localhost:4000/"
        );
        veggia.initialize(
            address(this),
            address(this),
            "http://localhost:4000/"
        );

        console.log("Admin address: %s", address(this));

        proxy = new VeggiaERC721Proxy(address(veggia), address(this));
    }
}
