// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console, Vm} from "forge-std/Test.sol";
import {VeggiaERC721} from "../src/VeggiaERC721.sol";
import {VeggiaERC721Proxy} from "../src/proxy/VeggiaERC721Proxy.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {MintHelper} from "./utils/MintHelper.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract VeggiaERC721ProxyInitializeTest is Test, ERC721Holder {
    using MintHelper for VeggiaERC721;

    VeggiaERC721Proxy public proxy;
    VeggiaERC721 public veggia;

    function test_initialize() public {
        string memory baseUri = "http://localhost:4000/";
        address serverSigner = vm.addr(uint256(SERVER_SIGNER));
        address initialOwner = address(0x1111);
        address owner = address(0x1234);
        address feeReceiver = address(0x5678);

        veggia = new VeggiaERC721();
        address implementation = address(veggia);

        vm.recordLogs();
        proxy = new VeggiaERC721Proxy(address(veggia), initialOwner);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Get the new deployed ProxyAdmin contract address
        (, address proxyAdmin) = abi.decode(entries[2].data, (address, address));

        veggia = VeggiaERC721(address(proxy));
        vm.prank(initialOwner);
        veggia.initialize(owner, feeReceiver, serverSigner, address(123456789), baseUri, "tests");

        assertEq(veggia.authoritySigner(), serverSigner);
        assertEq(veggia.owner(), owner);
        assertEq(veggia.feeReceiver(), feeReceiver);

        assertEq(veggia.freeMintLimit(), 6);
        assertEq(veggia.freeMintCooldown(), 24 hours);
        // assertEq(veggia.capsUsdPriceByQuantity(3), 0.0003 ether);
        // assertEq(veggia.capsUsdPriceByQuantity(9), 0.0006 ether);
        // assertEq(veggia.capsUsdPriceByQuantity(30), 0.0018 ether);
        assertEq(veggia.premiumCapsUsdPriceByQuantity(3), 1.99 ether);
        assertEq(veggia.premiumCapsUsdPriceByQuantity(9), 4.99 ether);
        assertEq(veggia.premiumCapsUsdPriceByQuantity(30), 9.99 ether);
        assertEq(veggia.premiumPackUsdPrice(), 99.99 ether);
        assertEq(address(veggia.pyth()), address(123456789));

        veggia.forceMint3(address(this), 1);
        assertEq(veggia.tokenURI(0), "http://localhost:4000/0");

        assertEq(proxy.implementation(), implementation);
        assertEq(proxy.admin(), proxyAdmin);
    }

    function test_initializeTwice() public {
        address initialOwner = address(0x1111);

        test_initialize();

        vm.prank(initialOwner);
        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721Proxy.ALREADY_INITIALIZED.selector));
        veggia.initialize(
            address(0x1234), address(0x5678), address(0x9999), address(0x654654), "http://localhost:4000/", "tests"
        );
    }

    function test_proxyCantReceiveEth() public {
        veggia = new VeggiaERC721();
        proxy = new VeggiaERC721Proxy(address(veggia), address(this));
        proxy.initialize(
            address(0x1234), address(0x5678), address(0x9999), address(0x654654), "http://localhost:4000/", "tests"
        );

        vm.expectRevert(abi.encodeWithSelector(VeggiaERC721Proxy.CAN_NOT_RECEIVE_ETHER.selector));
        payable(address(proxy)).transfer(1 ether);
    }
}
