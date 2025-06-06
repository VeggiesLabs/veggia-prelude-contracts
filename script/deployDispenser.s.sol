// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Dispenser} from "src/Dispenser.sol";

contract DeployDispenser is Script {
    function run() external {
        vm.startBroadcast();
        new Dispenser();
        vm.stopBroadcast();
    }
}
