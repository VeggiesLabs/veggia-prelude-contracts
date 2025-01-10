// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

abstract contract ERC721TransferLock is ERC721 {
    mapping(uint256 => bool) private _lockedTokens;

    error TransferLocked(uint256 tokenId);

    function _lockToken(uint256 tokenId) internal {
        _lockedTokens[tokenId] = true;
    }

    function unlockToken(uint256 tokenId) internal {
        _lockedTokens[tokenId] = false;
    }

    function isTokenLocked(uint256 tokenId) public view returns (bool) {
        return _lockedTokens[tokenId];
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override(ERC721) returns (address) {
        if (isTokenLocked(tokenId)) {
            revert TransferLocked(tokenId);
        }
        return super._update(to, tokenId, auth);
    }
}
