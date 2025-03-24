// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {VeggiaERC721} from "../../src/VeggiaERC721.sol";
import {SERVER_SIGNER} from "../utils/constants.sol";
import {Vm} from "forge-std/Vm.sol";
import {SignatureHelper} from "./SignatureHelper.sol";
import {MockPyth} from "@pythnetwork/MockPyth.sol";

library PythHelper {
    function createEthUpdate(MockPyth pyth, int64 ethPrice) public view returns (bytes[] memory) {
        bytes32 ETH_PRICE_FEED_ID = bytes32(uint256(0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace));

        bytes[] memory updateData = new bytes[](1);
        updateData[0] = pyth.createPriceFeedUpdateData(
            ETH_PRICE_FEED_ID,
            ethPrice * 100000, // price
            10 * 100000, // confidence
            -5, // exponent
            ethPrice * 100000, // emaPrice
            10 * 100000, // emaConfidence
            uint64(block.timestamp), // publishTime
            uint64(block.timestamp) // prevPublishTime
        );

        return updateData;
    }
}
