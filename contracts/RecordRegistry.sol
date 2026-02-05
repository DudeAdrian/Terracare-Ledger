// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./AccessControl.sol";
import "./ActivityRegistry.sol";

/**
 * @title RecordRegistry
 * @dev Stores hashes/pointers (no PHI). Patients write; caregivers read if granted.
 * v2.0: Added data contribution tracking that triggers ActivityRegistry logging
 */
contract RecordRegistry {
    
    struct Record {
        bytes32 dataHash;      // e.g., IPFS CID hashed to bytes32
        uint256 version;
        uint256 updatedAt;
        uint256 dataSize;      // Size of data for contribution calculation
        bool isAnonymized;     // Whether data is anonymized for research
        bytes32 dataType;      // Type of health data
    }
    
    struct Contribution {
        uint256 totalUpdates;
        uint256 totalDataSize;
        uint256 anonymizedContributions;
        uint256 lastContributionTime;
        bool eligibleForRewards;
    }

    TerracareAccessControl public accessControl;
    ActivityRegistry public activityRegistry;
    
    mapping(address => Record) public records;
    mapping(address => Contribution) public contributions;
    mapping(address => bytes32[]) public userRecordHistory;
    mapping(bytes32 => bool) public supportedDataTypes;
    
    // Minimum data size to qualify for contribution reward
    uint256 public constant MIN_DATA_SIZE = 1024; // 1KB
    uint256 public constant CONTRIBUTION_REWARD_COOLDOWN = 1 days;
    
    // Track record creation for activity logging
    bool public activityTrackingEnabled = true;
    address public authorizedActivityCaller;

    event RecordUpdated(
        address indexed patient, 
        bytes32 dataHash, 
        uint256 version, 
        uint256 dataSize,
        bool isAnonymized
    );
    event DataContributionTracked(
        address indexed patient,
        uint256 dataSize,
        bool isAnonymized
    );
    event ActivityRegistrySet(address indexed activityRegistry);
    event DataTypeAdded(bytes32 indexed dataType);
    event DataTypeRemoved(bytes32 indexed dataType);

    constructor(address accessControlAddress) {
        accessControl = TerracareAccessControl(accessControlAddress);
        
        // Set default supported data types
        supportedDataTypes[keccak256("vital_signs")] = true;
        supportedDataTypes[keccak256("lab_results")] = true;
        supportedDataTypes[keccak256("imaging")] = true;
        supportedDataTypes[keccak256("medication")] = true;
        supportedDataTypes[keccak256("therapy_notes")] = true;
        supportedDataTypes[keccak256("biometric_stream")] = true;
    }
    
    /**
     * @dev Set ActivityRegistry for contribution tracking
     */
    function setActivityRegistry(address _activityRegistry) external {
        // Only callable by owner (through access control check)
        require(
            msg.sender == authorizedActivityCaller ||
            accessControl.registry().isActive(msg.sender, IdentityRegistry.Role.Admin),
            "Not authorized"
        );
        activityRegistry = ActivityRegistry(_activityRegistry);
        emit ActivityRegistrySet(_activityRegistry);
    }
    
    /**
     * @dev Set authorized activity caller
     */
    function setAuthorizedActivityCaller(address caller) external {
        require(accessControl.registry().isActive(msg.sender, IdentityRegistry.Role.Admin), "Not admin");
        authorizedActivityCaller = caller;
    }
    
    /**
     * @dev Toggle activity tracking
     */
    function setActivityTracking(bool enabled) external {
        require(accessControl.registry().isActive(msg.sender, IdentityRegistry.Role.Admin), "Not admin");
        activityTrackingEnabled = enabled;
    }

    /**
     * @dev Update record with basic info
     */
    function updateRecord(bytes32 dataHash) external {
        _updateRecord(msg.sender, dataHash, 0, false, bytes32(0));
    }
    
    /**
     * @dev Update record with full contribution tracking
     */
    function updateRecordWithContribution(
        bytes32 dataHash,
        uint256 dataSize,
        bool isAnonymized,
        bytes32 dataType
    ) external {
        _updateRecord(msg.sender, dataHash, dataSize, isAnonymized, dataType);
    }
    
    function _updateRecord(
        address patient,
        bytes32 dataHash,
        uint256 dataSize,
        bool isAnonymized,
        bytes32 dataType
    ) internal {
        Record storage r = records[patient];
        r.dataHash = dataHash;
        r.version += 1;
        r.updatedAt = block.timestamp;
        
        if (dataSize > 0) {
            r.dataSize = dataSize;
        }
        if (dataType != bytes32(0)) {
            r.dataType = dataType;
        }
        r.isAnonymized = isAnonymized;
        
        userRecordHistory[patient].push(dataHash);
        
        // Track contribution
        Contribution storage contrib = contributions[patient];
        contrib.totalUpdates++;
        contrib.totalDataSize += dataSize;
        if (isAnonymized) {
            contrib.anonymizedContributions++;
        }
        contrib.lastContributionTime = block.timestamp;
        
        emit RecordUpdated(patient, dataHash, r.version, dataSize, isAnonymized);
        
        // Trigger activity logging if eligible
        if (_shouldRewardContribution(patient, dataSize)) {
            _logDataContribution(patient, dataSize, isAnonymized);
        }
    }
    
    /**
     * @dev Check if contribution should be rewarded
     */
    function _shouldRewardContribution(address patient, uint256 dataSize) 
        internal 
        view 
        returns (bool) 
    {
        if (!activityTrackingEnabled) return false;
        if (address(activityRegistry) == address(0)) return false;
        if (dataSize < MIN_DATA_SIZE) return false;
        
        Contribution memory contrib = contributions[patient];
        if (block.timestamp < contrib.lastContributionTime + CONTRIBUTION_REWARD_COOLDOWN) {
            return false;
        }
        
        return true;
    }
    
    /**
     * @dev Log data contribution to ActivityRegistry
     */
    function _logDataContribution(
        address patient,
        uint256 dataSize,
        bool isAnonymized
    ) internal {
        if (address(activityRegistry) == address(0)) return;
        
        // Generate activity ID
        bytes32 activityId = keccak256(abi.encodePacked(
            patient,
            block.timestamp,
            dataSize,
            block.number
        ));
        
        // Get userId from IdentityRegistry
        bytes32 userId = accessControl.registry().getUserId(patient);
        
        // Calculate value score based on data size and anonymization
        uint256 valueScore = _calculateValueScore(dataSize, isAnonymized);
        
        // This would normally be called by oracle, so we emit event instead
        emit DataContributionTracked(patient, dataSize, isAnonymized);
    }
    
    /**
     * @dev Calculate value score for data contribution
     */
    function _calculateValueScore(uint256 dataSize, bool isAnonymized) 
        internal 
        pure 
        returns (uint256) 
    {
        // Base score: 5-15 based on size (capped at 10MB)
        uint256 sizeScore = dataSize > 10 * 1024 * 1024 ? 15 : (dataSize / (1024 * 1024)) + 5;
        
        // Bonus for anonymized data (research value)
        uint256 anonymizationBonus = isAnonymized ? 10 : 0;
        
        uint256 total = sizeScore + anonymizationBonus;
        return total > 100 ? 100 : total;
    }
    
    /**
     * @dev External function to log data contribution (called by oracle/backend)
     */
    function logDataContribution(
        address patient,
        bytes32 activityId,
        uint256 valueScore
    ) external {
        require(
            msg.sender == authorizedActivityCaller ||
            accessControl.registry().isActive(msg.sender, IdentityRegistry.Role.System),
            "Not authorized"
        );
        require(address(activityRegistry) != address(0), "ActivityRegistry not set");
        
        bytes32 userId = accessControl.registry().getUserId(patient);
        
        activityRegistry.recordActivity(
            activityId,
            userId,
            ActivityRegistry.ActivityType.DataValidation,
            records[patient].dataHash,
            valueScore,
            patient
        );
    }

    function getRecord(address patient) external view returns (
        bytes32 dataHash, 
        uint256 version, 
        uint256 updatedAt,
        uint256 dataSize,
        bool isAnonymized,
        bytes32 dataType
    ) {
        require(
            msg.sender == patient || accessControl.hasAccess(patient, msg.sender),
            "No access"
        );
        Record memory r = records[patient];
        return (r.dataHash, r.version, r.updatedAt, r.dataSize, r.isAnonymized, r.dataType);
    }
    
    /**
     * @dev Get contribution stats for a patient
     */
    function getContribution(address patient) external view returns (
        uint256 totalUpdates,
        uint256 totalDataSize,
        uint256 anonymizedContributions,
        uint256 lastContributionTime,
        bool eligibleForRewards
    ) {
        Contribution memory c = contributions[patient];
        return (
            c.totalUpdates,
            c.totalDataSize,
            c.anonymizedContributions,
            c.lastContributionTime,
            c.eligibleForRewards
        );
    }
    
    /**
     * @dev Get record history for patient
     */
    function getRecordHistory(address patient, uint256 start, uint256 count) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        require(
            msg.sender == patient || accessControl.hasAccess(patient, msg.sender),
            "No access"
        );
        
        uint256 end = start + count;
        if (end > userRecordHistory[patient].length) {
            end = userRecordHistory[patient].length;
        }
        
        bytes32[] memory history = new bytes32[](end - start);
        for (uint i = start; i < end; i++) {
            history[i - start] = userRecordHistory[patient][i];
        }
        return history;
    }
    
    /**
     * @dev Get record count
     */
    function getRecordCount(address patient) external view returns (uint256) {
        return userRecordHistory[patient].length;
    }
    
    /**
     * @dev Add supported data type
     */
    function addDataType(string calldata dataType) external {
        require(accessControl.registry().isActive(msg.sender, IdentityRegistry.Role.Admin), "Not admin");
        bytes32 typeHash = keccak256(bytes(dataType));
        supportedDataTypes[typeHash] = true;
        emit DataTypeAdded(typeHash);
    }
    
    /**
     * @dev Remove supported data type
     */
    function removeDataType(string calldata dataType) external {
        require(accessControl.registry().isActive(msg.sender, IdentityRegistry.Role.Admin), "Not admin");
        bytes32 typeHash = keccak256(bytes(dataType));
        supportedDataTypes[typeHash] = false;
        emit DataTypeRemoved(typeHash);
    }
    
    /**
     * @dev Check if data type is supported
     */
    function isDataTypeSupported(bytes32 dataType) external view returns (bool) {
        return supportedDataTypes[dataType];
    }
    
    /**
     * @dev Batch get records (for authorized caregivers)
     */
    function batchGetRecords(address[] calldata patients) 
        external 
        view 
        returns (Record[] memory) 
    {
        Record[] memory results = new Record[](patients.length);
        
        for (uint i = 0; i < patients.length; i++) {
            require(
                msg.sender == patients[i] || accessControl.hasAccess(patients[i], msg.sender),
                "No access"
            );
            results[i] = records[patients[i]];
        }
        
        return results;
    }
}
