// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./AccessControl.sol";

/**
 * @title RecordRegistry
 * @dev Stores hashes/pointers (no PHI). Patients write; caregivers read if granted.
 */
contract RecordRegistry {
    struct Record {
        bytes32 dataHash; // e.g., IPFS CID hashed to bytes32 (use keccak256 of CID string)
        uint256 version;
        uint256 updatedAt;
    }

    AccessControl public accessControl;
    mapping(address => Record) public records; // patient => record

    event RecordUpdated(address indexed patient, bytes32 dataHash, uint256 version);

    constructor(address accessControlAddress) {
        accessControl = AccessControl(accessControlAddress);
    }

    function updateRecord(bytes32 dataHash) external {
        Record storage r = records[msg.sender];
        r.dataHash = dataHash;
        r.version += 1;
        r.updatedAt = block.timestamp;
        emit RecordUpdated(msg.sender, dataHash, r.version);
    }

    function getRecord(address patient) external view returns (bytes32 dataHash, uint256 version, uint256 updatedAt) {
        require(
            msg.sender == patient || accessControl.hasAccess(patient, msg.sender),
            "No access"
        );
        Record memory r = records[patient];
        return (r.dataHash, r.version, r.updatedAt);
    }
}
