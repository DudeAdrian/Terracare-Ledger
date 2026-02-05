// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IdentityRegistry.sol";
import "./TokenEngine.sol";

/**
 * @title TerracareAccessControl
 * @dev Per-record access grants/revokes with audit events
 * v2.0: Added token-gated access for premium features
 */
contract TerracareAccessControl {
    IdentityRegistry public registry;
    TokenEngine public tokenEngine;

    // patient => caregiver => allowed
    mapping(address => mapping(address => bool)) public access;
    
    // Premium access tiers (token-gated)
    enum AccessTier { Basic, Premium, Enterprise }
    mapping(address => AccessTier) public patientAccessTier;
    
    // Tier thresholds (in MINE)
    uint256 public constant PREMIUM_THRESHOLD = 500 * 10**18;   // 500 MINE
    uint256 public constant ENTERPRISE_THRESHOLD = 5000 * 10**18; // 5000 MINE
    
    // Feature access requirements (in WELL)
    mapping(bytes32 => uint256) public featureCosts; // feature hash => WELL cost
    mapping(address => mapping(bytes32 => bool)) public hasPaidForFeature;
    
    // Access expiration for time-limited access
    mapping(address => mapping(address => uint256)) public accessExpiry;
    
    // Emergency access (for critical situations)
    mapping(address => mapping(address => bool)) public emergencyAccess;
    
    // Audit tracking
    mapping(address => AccessLog[]) public accessLogs;
    
    struct AccessLog {
        address accessor;
        uint256 timestamp;
        string action;
        bool granted;
    }

    event AccessGranted(address indexed patient, address indexed caregiver, uint256 expiry);
    event AccessRevoked(address indexed patient, address indexed caregiver);
    event AccessTierUpgraded(address indexed patient, AccessTier tier);
    event FeaturePurchased(address indexed patient, bytes32 feature, uint256 cost);
    event EmergencyAccessGranted(address indexed patient, address indexed caregiver);
    event EmergencyAccessRevoked(address indexed patient, address indexed caregiver);
    event TokenEngineSet(address indexed tokenEngine);

    constructor(address registryAddress) {
        registry = IdentityRegistry(registryAddress);
    }
    
    /**
     * @dev Set TokenEngine address
     */
    function setTokenEngine(address _tokenEngine) external {
        (, bool active, , , ) = registry.get(msg.sender);
        require(active && msg.sender == address(registry), "Not authorized");
        tokenEngine = TokenEngine(_tokenEngine);
        emit TokenEngineSet(_tokenEngine);
    }

    function grant(address caregiver) external {
        _grantAccess(msg.sender, caregiver, 0);
    }
    
    /**
     * @dev Grant time-limited access
     */
    function grantWithExpiry(address caregiver, uint256 duration) external {
        _grantAccess(msg.sender, caregiver, block.timestamp + duration);
    }
    
    function _grantAccess(address patient, address caregiver, uint256 expiry) internal {
        access[patient][caregiver] = true;
        if (expiry > 0) {
            accessExpiry[patient][caregiver] = expiry;
        }
        
        accessLogs[patient].push(AccessLog({
            accessor: caregiver,
            timestamp: block.timestamp,
            action: "GRANT",
            granted: true
        }));
        
        emit AccessGranted(patient, caregiver, expiry);
    }

    function revoke(address caregiver) external {
        access[msg.sender][caregiver] = false;
        delete accessExpiry[msg.sender][caregiver];
        
        accessLogs[msg.sender].push(AccessLog({
            accessor: caregiver,
            timestamp: block.timestamp,
            action: "REVOKE",
            granted: false
        }));
        
        emit AccessRevoked(msg.sender, caregiver);
    }

    function hasAccess(address patient, address caregiver) external view returns (bool) {
        // Check regular access
        if (access[patient][caregiver]) {
            // Check expiry if set
            uint256 expiry = accessExpiry[patient][caregiver];
            if (expiry > 0 && block.timestamp > expiry) {
                return false;
            }
            return true;
        }
        
        // Check emergency access
        if (emergencyAccess[patient][caregiver]) {
            return true;
        }
        
        return false;
    }
    
    /**
     * @dev Require MINE token balance for access modifier
     */
    modifier requireMINE(uint256 minBalance) {
        require(address(tokenEngine) != address(0), "TokenEngine not set");
        require(tokenEngine.getTotalMINE(msg.sender) >= minBalance, "Insufficient MINE");
        _;
    }
    
    /**
     * @dev Require WELL token balance for access modifier
     */
    modifier requireWELL(uint256 minBalance) {
        require(address(tokenEngine) != address(0), "TokenEngine not set");
        require(tokenEngine.balanceOf(msg.sender) >= minBalance, "Insufficient WELL");
        _;
    }
    
    /**
     * @dev Check if user has premium access (based on MINE balance)
     */
    function hasPremiumAccess(address patient) external view returns (bool) {
        if (address(tokenEngine) == address(0)) return false;
        return tokenEngine.getTotalMINE(patient) >= PREMIUM_THRESHOLD;
    }
    
    /**
     * @dev Check if user has enterprise access
     */
    function hasEnterpriseAccess(address patient) external view returns (bool) {
        if (address(tokenEngine) == address(0)) return false;
        return tokenEngine.getTotalMINE(patient) >= ENTERPRISE_THRESHOLD;
    }
    
    /**
     * @dev Get user's access tier
     */
    function getAccessTier(address patient) external view returns (AccessTier) {
        if (address(tokenEngine) == address(0)) return AccessTier.Basic;
        
        uint256 mineBalance = tokenEngine.getTotalMINE(patient);
        if (mineBalance >= ENTERPRISE_THRESHOLD) return AccessTier.Enterprise;
        if (mineBalance >= PREMIUM_THRESHOLD) return AccessTier.Premium;
        return AccessTier.Basic;
    }
    
    /**
     * @dev Purchase premium feature with WELL tokens
     */
    function purchaseFeature(bytes32 featureHash) external {
        require(address(tokenEngine) != address(0), "TokenEngine not set");
        uint256 cost = featureCosts[featureHash];
        require(cost > 0, "Feature not available");
        require(!hasPaidForFeature[msg.sender][featureHash], "Already purchased");
        
        // Burn WELL tokens as payment
        tokenEngine.burnWELL(cost);
        
        hasPaidForFeature[msg.sender][featureHash] = true;
        
        emit FeaturePurchased(msg.sender, featureHash, cost);
    }
    
    /**
     * @dev Set feature cost (admin only via governance)
     */
    function setFeatureCost(bytes32 featureHash, uint256 cost) external {
        // Can only be called via governance proposal
        require(msg.sender == address(this) || msg.sender == address(registry), "Not authorized");
        featureCosts[featureHash] = cost;
    }
    
    /**
     * @dev Grant emergency access (for critical situations)
     * Can be granted by validators or with sufficient stake
     */
    function grantEmergencyAccess(address patient, address caregiver) external {
        require(
            registry.isActive(msg.sender, IdentityRegistry.Role.Admin) ||
            registry.isActive(msg.sender, IdentityRegistry.Role.System) ||
            (address(tokenEngine) != address(0) && 
             tokenEngine.getTotalMINE(msg.sender) >= ENTERPRISE_THRESHOLD),
            "Not authorized for emergency access"
        );
        
        emergencyAccess[patient][caregiver] = true;
        emit EmergencyAccessGranted(patient, caregiver);
    }
    
    /**
     * @dev Revoke emergency access
     */
    function revokeEmergencyAccess(address patient, address caregiver) external {
        require(
            msg.sender == patient ||
            registry.isActive(msg.sender, IdentityRegistry.Role.Admin),
            "Not authorized"
        );
        
        emergencyAccess[patient][caregiver] = false;
        emit EmergencyAccessRevoked(patient, caregiver);
    }
    
    /**
     * @dev Get access logs for patient
     */
    function getAccessLogs(address patient, uint256 start, uint256 count) 
        external 
        view 
        returns (AccessLog[] memory) 
    {
        uint256 end = start + count;
        if (end > accessLogs[patient].length) end = accessLogs[patient].length;
        
        AccessLog[] memory logs = new AccessLog[](end - start);
        for (uint i = start; i < end; i++) {
            logs[i - start] = accessLogs[patient][i];
        }
        return logs;
    }
    
    /**
     * @dev Get total access log count
     */
    function getAccessLogCount(address patient) external view returns (uint256) {
        return accessLogs[patient].length;
    }
    
    /**
     * @dev Check and clean expired access
     */
    function cleanExpiredAccess(address patient, address caregiver) external {
        uint256 expiry = accessExpiry[patient][caregiver];
        if (expiry > 0 && block.timestamp > expiry) {
            access[patient][caregiver] = false;
            delete accessExpiry[patient][caregiver];
        }
    }
}
