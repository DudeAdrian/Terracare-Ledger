// SPDX-License-Identifier: MIT
/**
 * @title IERC5192 - Soulbound Token Standard
 * @notice Minimal interface for soulbound (non-transferable) NFTs
 * @dev ERC-5192 is an extension of ERC-721 that prevents transfers
 */
pragma solidity ^0.8.24;

interface IERC5192 {
    /// @notice Emitted when the locking status is changed to locked.
    /// @dev If a token is minted and the status is locked, this event should be emitted.
    /// @param tokenId The identifier for a token.
    event Locked(uint256 indexed tokenId);

    /// @notice Emitted when the locking status is changed to unlocked.
    /// @dev If a token is minted and the status is unlocked, this event should be emitted.
    /// @param tokenId The identifier for a token.
    event Unlocked(uint256 indexed tokenId);

    /// @notice Returns the locking status of a Soulbound Token
    /// @dev If a token exists and is locked, this should return true; otherwise false
    /// @param tokenId The identifier for a token.
    function locked(uint256 tokenId) external view returns (bool);
}
