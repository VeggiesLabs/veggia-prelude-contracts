// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract ERC721TransferLock {
    mapping(uint256 => bool) private _lockedTokens;

    function _lockToken(uint256 tokenId) internal {
        _lockedTokens[tokenId] = true;
    }

    function unlockToken(uint256 tokenId) internal {
        _lockedTokens[tokenId] = false;
    }

    function isTokenLocked(uint256 tokenId) public view returns (bool) {
        return _lockedTokens[tokenId];
    }
}
