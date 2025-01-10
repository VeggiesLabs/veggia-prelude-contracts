// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {VeggiaERC721} from "../VeggiaERC721.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract VeggiaERC721Proxy is TransparentUpgradeableProxy {
    bool initialized;

    error ALREADY_INITIALIZED();
    error INITIALIZATION_FAILED();
    error CAN_NOT_RECEIVE_ETHER();

    constructor(address logic, address initialOwner) TransparentUpgradeableProxy(logic, initialOwner, bytes("")) {}

    /**
     * @notice Initialize the contract.
     * @param _feeReceiver The address that will receive the egg price.
     * @param _baseUri The base URI of the token.
     */
    function initialize(address owner, address _feeReceiver, string memory _baseUri) external {
        if (initialized) revert ALREADY_INITIALIZED();

        (bool success,) = _implementation().delegatecall(
            abi.encodeWithSelector(VeggiaERC721.initialize.selector, owner, _feeReceiver, _baseUri)
        );

        if (!success) revert INITIALIZATION_FAILED();
    }

    /**
     * @notice Get the implementation address.
     */
    function implementation() public view returns (address) {
        return _implementation();
    }

    /**
     * @notice Get the admin address.
     */
    function admin() public view returns (address) {
        return _proxyAdmin();
    }

    receive() external payable {
        revert CAN_NOT_RECEIVE_ETHER();
    }
}
