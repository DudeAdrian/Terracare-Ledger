// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title AuditLog
 * @dev Append-only event emitter for access and data operations
 */
contract AuditLog {
    event AccessEvent(address indexed actor, address indexed subject, string action, uint256 timestamp, bytes32 refHash);
    event DataEvent(address indexed actor, string action, uint256 timestamp, bytes32 dataHash, uint256 version);

    function logAccess(address subject, string calldata action, bytes32 refHash) external {
        emit AccessEvent(msg.sender, subject, action, block.timestamp, refHash);
    }

    function logData(string calldata action, bytes32 dataHash, uint256 version) external {
        emit DataEvent(msg.sender, action, block.timestamp, dataHash, version);
    }
}
