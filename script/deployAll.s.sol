// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {VeggiaERC721} from "src/VeggiaERC721.sol";
import {VeggiaERC721Proxy} from "src/proxy/VeggiaERC721Proxy.sol";

contract DeployAll is Script {
    address owner;
    address feeReceiver;
    address authoritySigner;
    address pyth;
    string baseURI;
    string env;

    function run() external {
        loadEnvVars();

        vm.startBroadcast();
        VeggiaERC721 veggiaImplementation = new VeggiaERC721();
        VeggiaERC721Proxy veggiaProxy = new VeggiaERC721Proxy(address(veggiaImplementation), owner);

        veggiaProxy.initialize(owner, feeReceiver, authoritySigner, pyth, baseURI, env);

        vm.stopBroadcast();
    }

    function loadEnvVars() internal {
        owner = vm.envAddress("OWNER");
        feeReceiver = vm.envAddress("FEE_RECEIVER");
        authoritySigner = vm.envAddress("SERVER_SIGNER");
        pyth = vm.envAddress("PYTH_CONTRACT");
        baseURI = vm.envString("VEGGIA_BASE_URI");
        env = vm.envString("ENV");
    }
}
