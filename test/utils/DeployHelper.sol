// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {VeggiaERC721} from "src/VeggiaERC721.sol";
import {VeggiaERC721Proxy} from "src/proxy/VeggiaERC721Proxy.sol";
import {Vm} from "forge-std/Vm.sol";
import {MockPyth} from "@pythnetwork/MockPyth.sol";
import {SignatureHelper} from "./SignatureHelper.sol";

library DeployHelper {
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm internal constant vm = Vm(VM_ADDRESS);

    function deployVeggia(address owner, address feeReceiver, address authoritySigner, string memory baseURI)
        internal
        returns (VeggiaERC721)
    {
        VeggiaERC721 veggiaImplementation = new VeggiaERC721();
        VeggiaERC721Proxy veggiaProxy = new VeggiaERC721Proxy(address(veggiaImplementation), owner);

        vm.prank(owner);
        veggiaProxy.initialize(owner, feeReceiver, authoritySigner, address(0), baseURI);

        return VeggiaERC721(address(veggiaProxy));
    }

    function deployVeggiaWithPyth(address owner, address feeReceiver, address authoritySigner, string memory baseURI)
        internal
        returns (VeggiaERC721, MockPyth)
    {
        VeggiaERC721 veggiaImplementation = new VeggiaERC721();
        VeggiaERC721Proxy veggiaProxy = new VeggiaERC721Proxy(address(veggiaImplementation), owner);

        MockPyth pyth = new MockPyth(60, 1);

        vm.prank(owner);
        veggiaProxy.initialize(owner, feeReceiver, authoritySigner, address(pyth), baseURI);

        return (VeggiaERC721(address(veggiaProxy)), pyth);
    }

    function unlockSuperPassFor(VeggiaERC721 veggia, bytes32 authoritySigner, address owner) internal {
        bytes memory signature = SignatureHelper.signUnlockForAs(veggia, authoritySigner, owner);
        VeggiaERC721.UpdateSuperPassRequest memory request = VeggiaERC721.UpdateSuperPassRequest(owner, true);
        veggia.updateSuperPassWithSignature(request, signature);
    }
}
