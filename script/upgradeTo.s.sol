// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {VeggiaERC721} from "src/VeggiaERC721.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent//ProxyAdmin.sol";

contract UpgradeTo is Script {
	address owner;
	address feeReceiver;
	address capsSigner;
	string baseURI;

	bytes32 internal constant ADMIN_SLOT =
		0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

	function run() external {
		vm.startBroadcast();
		address _veggiaProxy = payable(vm.envAddress("PROXY_ADDRESS"));
		ProxyAdmin admin = ProxyAdmin(
			address(uint160(uint256(vm.load(_veggiaProxy, ADMIN_SLOT))))
		);

		VeggiaERC721 newImplementation = new VeggiaERC721();

		admin.upgradeAndCall(
			ITransparentUpgradeableProxy(_veggiaProxy),
			address(newImplementation),
			abi.encode()
		);

		vm.stopBroadcast();
	}
}
