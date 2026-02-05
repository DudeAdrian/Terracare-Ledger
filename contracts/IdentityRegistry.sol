// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TokenEngine.sol";

/**
 * @title IdentityRegistry
 * @dev Minimal identity/role registry for Terracare (permissioned, tokenless)
 * v2.0: Added cooperative member role and MINE token integration
 */
contract IdentityRegistry {
    enum Role { Unknown, Patient, Caregiver, Admin, System, CooperativeMember }

    struct Identity {
        Role role;
        bool active;
        uint256 createdAt;
        bytes32 userId;           // Hashed user identifier
        bool isCooperativeMember; // Cooperative membership status
        uint256 memberSince;      // When became cooperative member
    }

    address public owner;
    mapping(address => Identity) public identities;
    mapping(bytes32 => address) public userIdToAddress;  // userId => address
    
    // Token engine reference
    TokenEngine public tokenEngine;
    
    // Cooperative membership threshold
    uint256 public constant MEMBERSHIP_MINE_THRESHOLD = 1000 * 10**18; // 1000 MINE to become member

    event IdentityRegistered(address indexed account, Role role, bytes32 userId);
    event IdentityUpdated(address indexed account, Role role, bool active);
    event CooperativeMemberAdded(address indexed account, uint256 mineBalance);
    event CooperativeMemberRemoved(address indexed account);
    event TokenEngineSet(address indexed tokenEngine);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Set TokenEngine address (called after deployment)
     */
    function setTokenEngine(address _tokenEngine) external onlyOwner {
        require(_tokenEngine != address(0), "Invalid address");
        tokenEngine = TokenEngine(_tokenEngine);
        emit TokenEngineSet(_tokenEngine);
    }

    function register(address account, Role role) external onlyOwner {
        require(account != address(0), "Bad account");
        require(identities[account].createdAt == 0, "Already registered");
        
        bytes32 userId = keccak256(abi.encodePacked(account, block.timestamp));
        
        identities[account] = Identity({
            role: role,
            active: true,
            createdAt: block.timestamp,
            userId: userId,
            isCooperativeMember: false,
            memberSince: 0
        });
        
        userIdToAddress[userId] = account;
        
        emit IdentityRegistered(account, role, userId);
    }
    
    /**
     * @dev Register with existing userId (for migration/sync)
     */
    function registerWithUserId(
        address account, 
        Role role, 
        bytes32 userId
    ) external onlyOwner {
        require(account != address(0), "Bad account");
        require(identities[account].createdAt == 0, "Already registered");
        require(userIdToAddress[userId] == address(0), "UserId exists");
        
        identities[account] = Identity({
            role: role,
            active: true,
            createdAt: block.timestamp,
            userId: userId,
            isCooperativeMember: false,
            memberSince: 0
        });
        
        userIdToAddress[userId] = account;
        
        emit IdentityRegistered(account, role, userId);
    }

    function update(address account, Role role, bool active) external onlyOwner {
        Identity storage id = identities[account];
        require(id.createdAt != 0, "Not registered");
        id.role = role;
        id.active = active;
        emit IdentityUpdated(account, role, active);
    }

    function get(address account) external view returns (
        Role role, 
        bool active, 
        uint256 createdAt,
        bytes32 userId,
        bool isCooperativeMember
    ) {
        Identity memory id = identities[account];
        return (id.role, id.active, id.createdAt, id.userId, id.isCooperativeMember);
    }

    function isActive(address account, Role role) external view returns (bool) {
        Identity memory id = identities[account];
        return id.active && id.role == role;
    }
    
    /**
     * @dev Get userId for an address
     */
    function getUserId(address account) external view returns (bytes32) {
        return identities[account].userId;
    }
    
    /**
     * @dev Get address for a userId
     */
    function getAddressByUserId(bytes32 userId) external view returns (address) {
        return userIdToAddress[userId];
    }
    
    /**
     * @dev Check and update cooperative membership based on MINE balance
     * Can be called by anyone (gasless check)
     */
    function checkCooperativeMembership(address account) external returns (bool) {
        Identity storage id = identities[account];
        require(id.createdAt != 0, "Not registered");
        require(address(tokenEngine) != address(0), "TokenEngine not set");
        
        uint256 mineBalance = tokenEngine.getTotalMINE(account);
        bool shouldBeMember = mineBalance >= MEMBERSHIP_MINE_THRESHOLD;
        
        if (shouldBeMember && !id.isCooperativeMember) {
            id.isCooperativeMember = true;
            id.memberSince = block.timestamp;
            emit CooperativeMemberAdded(account, mineBalance);
        } else if (!shouldBeMember && id.isCooperativeMember) {
            id.isCooperativeMember = false;
            id.memberSince = 0;
            emit CooperativeMemberRemoved(account);
        }
        
        return id.isCooperativeMember;
    }
    
    /**
     * @dev Check cooperative membership without updating
     */
    function checkMembershipStatus(address account) external view returns (bool) {
        return identities[account].isCooperativeMember;
    }
    
    /**
     * @dev Batch check cooperative memberships (gas efficient)
     */
    function batchCheckMemberships(address[] calldata accounts) external {
        for (uint i = 0; i < accounts.length; i++) {
            this.checkCooperativeMembership(accounts[i]);
        }
    }
    
    /**
     * @dev Force set cooperative membership (admin only)
     */
    function setCooperativeMember(address account, bool isMember) external onlyOwner {
        Identity storage id = identities[account];
        require(id.createdAt != 0, "Not registered");
        
        if (isMember && !id.isCooperativeMember) {
            id.isCooperativeMember = true;
            id.memberSince = block.timestamp;
            emit CooperativeMemberAdded(account, 0);
        } else if (!isMember && id.isCooperativeMember) {
            id.isCooperativeMember = false;
            id.memberSince = 0;
            emit CooperativeMemberRemoved(account);
        }
    }
    
    /**
     * @dev Get MINE balance for cooperative member
     */
    function getMemberMineBalance(address account) external view returns (uint256) {
        if (address(tokenEngine) == address(0)) return 0;
        return tokenEngine.getTotalMINE(account);
    }
    
    /**
     * @dev Get voting power for member (for governance)
     */
    function getMemberVotingPower(address account) external view returns (uint256) {
        if (address(tokenEngine) == address(0)) return 0;
        return tokenEngine.getVotingPower(account);
    }
    
    /**
     * @dev Modifier: Require cooperative membership
     */
    modifier onlyCooperativeMember() {
        require(identities[msg.sender].isCooperativeMember, "Not a cooperative member");
        _;
    }
    
    /**
     * @dev Modifier: Require minimum MINE balance
     */
    modifier requireMINEBalance(uint256 minBalance) {
        require(address(tokenEngine) != address(0), "TokenEngine not set");
        require(tokenEngine.getTotalMINE(msg.sender) >= minBalance, "Insufficient MINE");
        _;
    }
}
