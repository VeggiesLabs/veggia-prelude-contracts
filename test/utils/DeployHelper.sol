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
        veggiaProxy.initialize(owner, feeReceiver, authoritySigner, address(0), baseURI, "tests");

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
        veggiaProxy.initialize(owner, feeReceiver, authoritySigner, address(pyth), baseURI, "tests");

        return (VeggiaERC721(address(veggiaProxy)), pyth);
    }

    function updateSuperPassFor(VeggiaERC721 veggia, bytes32 authoritySigner, address owner, bool unlocked) internal {
        uint256 index = uint256(keccak256(abi.encodePacked(owner, unlocked)));
        bytes memory signature = SignatureHelper.signUpdateForAs(veggia, authoritySigner, owner, index, unlocked);
        VeggiaERC721.UpdateSuperPassRequest memory request = VeggiaERC721.UpdateSuperPassRequest(owner, index, unlocked);
        veggia.updateSuperPassWithSignature(request, signature);
    }
}
