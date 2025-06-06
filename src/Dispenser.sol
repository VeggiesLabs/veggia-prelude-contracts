// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Dispenser
 * @author @VeggiesLabs
 */
contract Dispenser is ReentrancyGuard {
    error InsufficientValue();
    error InvalidAmountsLength();
    error TransferFailed(address receiver, uint256 amount);

    /**
     * @notice Distributes ETH to multiple addresses.
     * @param receivers The addresses to receive the ETH.
     * @param amounts The amounts of ETH to send to each address.
     */
    function distributeEth(address[] calldata receivers, uint256[] calldata amounts) external payable nonReentrant {
        if (receivers.length != amounts.length) {
            revert InvalidAmountsLength();
        }

        uint256 totalAmount;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        if (msg.value < totalAmount) {
            revert InsufficientValue();
        }

        for (uint256 i = 0; i < receivers.length; i++) {
            (bool success,) = payable(receivers[i]).call{value: amounts[i]}("");
            if (!success) {
                revert TransferFailed(receivers[i], amounts[i]);
            }
        }
    }

    /**
     * @notice Distributes ERC20 tokens to multiple addresses.
     * @notice This function requires the caller to have approved the contract to spend the tokens on their behalf.
     * @param token The ERC20 token to distribute.
     * @param receivers The addresses to receive the tokens.
     * @param amounts The amounts of tokens to send to each address.
     */
    function distributeTokens(IERC20 token, address[] calldata receivers, uint256[] calldata amounts) external {
        if (receivers.length != amounts.length) {
            revert InvalidAmountsLength();
        }

        uint256 totalAmount;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        if (token.balanceOf(msg.sender) < totalAmount) {
            revert InsufficientValue();
        }

        for (uint256 i = 0; i < receivers.length; i++) {
            token.transferFrom(msg.sender, receivers[i], amounts[i]);
        }
    }
}
