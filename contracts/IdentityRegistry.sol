// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IdentityRegistry
 * @dev Minimal identity/role registry for Terracare (permissioned, tokenless)
 */
contract IdentityRegistry {
    enum Role { Unknown, Patient, Caregiver, Admin, System }

    struct Identity {
        Role role;
        bool active;
        uint256 createdAt;
    }

    address public owner;
    mapping(address => Identity) public identities;

    event IdentityRegistered(address indexed account, Role role);
    event IdentityUpdated(address indexed account, Role role, bool active);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function register(address account, Role role) external onlyOwner {
        require(account != address(0), "Bad account");
        identities[account] = Identity({
            role: role,
            active: true,
            createdAt: block.timestamp
        });
        emit IdentityRegistered(account, role);
    }

    function update(address account, Role role, bool active) external onlyOwner {
        Identity storage id = identities[account];
        require(id.createdAt != 0, "Not registered");
        id.role = role;
        id.active = active;
        emit IdentityUpdated(account, role, active);
    }

    function get(address account) external view returns (Role role, bool active, uint256 createdAt) {
        Identity memory id = identities[account];
        return (id.role, id.active, id.createdAt);
    }

    function isActive(address account, Role role) external view returns (bool) {
        Identity memory id = identities[account];
        return id.active && id.role == role;
    }
}
