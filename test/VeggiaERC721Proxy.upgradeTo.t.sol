// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {VeggiaERC721Proxy} from "../src/proxy/VeggiaERC721Proxy.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {DeployHelper} from "./utils/DeployHelper.sol";

contract VeggiaERC721ProxyTest is Test {
    VeggiaERC721Proxy public proxy;
    VeggiaERC721 public veggia;

    function setUp() public {
        veggia = new VeggiaERC721();
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        veggia = DeployHelper.deployVeggia(address(this), address(this), serverSigner, "http://localhost:4000/");

        proxy = new VeggiaERC721Proxy(address(veggia), address(this));
    }
}
