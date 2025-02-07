// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {VeggiaERC721} from "../VeggiaERC721.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title VeggiaERC721Proxy
 * @author @VeggiesLabs
 * @notice A proxy contract to upgrade the VeggiaERC721 contract.
 */
contract VeggiaERC721Proxy is TransparentUpgradeableProxy {
    /// @dev The initialization status of the contract.
    bytes32 initializedSlot = keccak256("VeggiaERC721Proxy.initialized");

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */
    error ALREADY_INITIALIZED();
    error INITIALIZATION_FAILED();
    error CAN_NOT_RECEIVE_ETHER();
    error UNAUTHORIZED();

    constructor(address logic, address initialOwner) TransparentUpgradeableProxy(logic, initialOwner, bytes("")) {}

    /**
     * @notice Initialize the contract.
     * @param owner The owner of the contract.
     * @param _feeReceiver The address that will receive the egg price.
     * @param _capsSigner The address that will sign the caps.
     * @param _baseUri The base URI of the token.
     */
    function initialize(address owner, address _feeReceiver, address _capsSigner, string memory _baseUri) external {
        if (msg.sender != ProxyAdmin(_proxyAdmin()).owner()) {
            revert UNAUTHORIZED();
        }
        if (initialized()) revert ALREADY_INITIALIZED();

        (bool success,) = _implementation().delegatecall(
            abi.encodeWithSelector(VeggiaERC721.initialize.selector, owner, _feeReceiver, _capsSigner, _baseUri)
        );

        if (!success) revert INITIALIZATION_FAILED();
        setInitialized();
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

    /**
     * @notice Get the initialized status of the contract.
     */
    function initialized() private view returns (bool) {
        bool _initialized;
        bytes32 _initializedSlot = initializedSlot;
        assembly {
            _initialized := sload(_initializedSlot)
        }
        return _initialized;
    }

    /**
     * @notice Set the initialized status of the contract to true.
     */
    function setInitialized() private {
        bytes32 _initializedSlot = initializedSlot;
        assembly {
            sstore(_initializedSlot, 1)
        }
    }

    /**
     * @notice Revert with a custom message when receiving ether.
     */
    receive() external payable {
        revert CAN_NOT_RECEIVE_ETHER();
    }
}
