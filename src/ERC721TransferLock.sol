// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title ERC721TransferLock
 * @dev ERC721TransferLock is an ERC721 contract that allows locking of token transfers.
 * @dev Locked tokens cannot be unlocked.
 */
abstract contract ERC721TransferLock is ERC721 {
    /// @dev Mapping of locked tokens.
    mapping(uint256 => bool) private _lockedTokens;

    /// @dev Emitted when a token transfer is locked.
    error TransferLocked(uint256 tokenId);

    /// @dev Locks a token.
    function _lockToken(uint256 tokenId) internal {
        _lockedTokens[tokenId] = true;
    }

    /// @dev Checks if a token is locked.
    function isTokenLocked(uint256 tokenId) public view returns (bool) {
        return _lockedTokens[tokenId];
    }

    /// @dev Overrides ERC721#_update to revert if the token is locked.
    function _update(address to, uint256 tokenId, address auth) internal virtual override(ERC721) returns (address) {
        if (isTokenLocked(tokenId)) {
            revert TransferLocked(tokenId);
        }
        return super._update(to, tokenId, auth);
    }
}
