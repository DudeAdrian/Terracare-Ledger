// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IdentityRegistry.sol";

/**
 * @title AccessControl
 * @dev Per-record access grants/revokes with audit events
 */
contract AccessControl {
    IdentityRegistry public registry;

    // patient => caregiver => allowed
    mapping(address => mapping(address => bool)) public access;

    event AccessGranted(address indexed patient, address indexed caregiver);
    event AccessRevoked(address indexed patient, address indexed caregiver);

    constructor(address registryAddress) {
        registry = IdentityRegistry(registryAddress);
    }

    modifier onlyPatient(address patient) {
        (, bool active, ) = registry.get(patient);
        require(active, "Patient inactive");
        require(msg.sender == patient, "Not patient");
        _;
    }

    function grant(address caregiver) external {
        access[msg.sender][caregiver] = true;
        emit AccessGranted(msg.sender, caregiver);
    }

    function revoke(address caregiver) external {
        access[msg.sender][caregiver] = false;
        emit AccessRevoked(msg.sender, caregiver);
    }

    function hasAccess(address patient, address caregiver) external view returns (bool) {
        return access[patient][caregiver];
    }
}
