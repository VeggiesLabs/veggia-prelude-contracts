// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console, Vm} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {VeggiaERC721Proxy} from "../src/proxy/VeggiaERC721Proxy.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {MintHelper} from "./utils/MintHelper.sol";

contract VeggiaERC721ProxyInitializeTest is Test {
    using MintHelper for VeggiaERC721;

    VeggiaERC721Proxy public proxy;
    VeggiaERC721 public veggia;

    function test_initialize() public {
        string memory baseUri = "http://localhost:4000/";
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        address initialOwner = address(0x1111);
        address owner = address(0x1234);
        address feeReceiver = address(0x5678);

        veggia = new VeggiaERC721(address(0), "");
        address implementation = address(veggia);

        vm.recordLogs();
        proxy = new VeggiaERC721Proxy(address(veggia), initialOwner);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Get the new deployed ProxyAdmin contract address
        (, address proxyAdmin) = abi.decode(entries[2].data, (address, address));

        veggia = VeggiaERC721(address(proxy));
        vm.prank(initialOwner);
        veggia.initialize(owner, feeReceiver, serverSigner, baseUri);

        assertEq(veggia.capsSigner(), serverSigner);
        assertEq(veggia.owner(), owner);
        assertEq(veggia.feeReceiver(), feeReceiver);

        assertEq(veggia.freeMintLimit(), 6);
        assertEq(veggia.freeMintCooldown(), 12 hours);
        assertEq(veggia.capsPriceByQuantity(3), 0.0003 ether);
        assertEq(veggia.capsPriceByQuantity(9), 0.0006 ether);
        assertEq(veggia.capsPriceByQuantity(30), 0.0018 ether);
        assertEq(veggia.premiumCapsPriceByQuantity(3), 0.0009 ether);
        assertEq(veggia.premiumCapsPriceByQuantity(9), 0.00225 ether);
        assertEq(veggia.premiumCapsPriceByQuantity(30), 0.0054 ether);
        assertEq(veggia.premiumPackPrice(), 0.0036 ether);

        veggia.forceMint3(address(this), 1);
        assertEq(veggia.tokenURI(0), "http://localhost:4000/0");

        assertEq(proxy.implementation(), implementation);
        assertEq(proxy.admin(), proxyAdmin);
    }

    function test_proxyCantReceiveEth() public {
        veggia = new VeggiaERC721(address(0), "");
        proxy = new VeggiaERC721Proxy(address(veggia), address(this));
        proxy.initialize(address(0x1234), address(0x5678), address(0x9999), "http://localhost:4000/");

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721Proxy.CAN_NOT_RECEIVE_ETHER.selector));
        payable(address(proxy)).transfer(1 ether);
    }
}
