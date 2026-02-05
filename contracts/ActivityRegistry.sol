// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TokenEngine.sol";
import "./IdentityRegistry.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ActivityRegistry
 * @dev Logs user activities and triggers MINE token minting
 * - Anti-gaming: 100 points/day/user limit
 * - Activity proofs stored on-chain with IPFS hash reference
 * - Only callable by authorized oracles/backend
 */
contract ActivityRegistry is AccessControl, ReentrancyGuard {
    
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    TokenEngine public tokenEngine;
    IdentityRegistry public identityRegistry;
    
    // Activity types
    enum ActivityType { 
        BiometricStream,    // Continuous health data from wearables
        TherapyCompletion,  // Completed therapy session
        DataValidation,     // Validated health data contribution
        Referral,           // Referred new user
        SurveyCompletion,   // Completed health survey
        PreventiveCare      // Proactive health action
    }
    
    // Activity proof struct
    struct ActivityProof {
        bytes32 userId;           // Hashed user identifier
        ActivityType activityType;
        uint256 timestamp;
        bytes32 dataHash;         // IPFS hash of detailed data
        uint256 valueScore;       // 1-100 points based on quality/impact
        address validator;        // AI oracle/validator that signed
        bool rewarded;            // Whether MINE was minted
    }
    
    // Storage
    mapping(bytes32 => ActivityProof) public activityProofs;
    mapping(bytes32 => uint256) public dailyPoints;  // userId + day => points
    mapping(bytes32 => uint256) public totalUserPoints;
    mapping(ActivityType => uint256) public activityTypeCount;
    
    bytes32[] public allActivityIds;
    
    // Rate limiting
    uint256 public constant DAILY_POINTS_CAP = 100;  // Max 100 points per day per user
    uint256 public constant DAY_IN_SECONDS = 86400;
    
    // Value score parameters (set by governance)
    mapping(ActivityType => uint256) public baseValueScores;
    
    // Events
    event ActivityRecorded(
        bytes32 indexed activityId,
        bytes32 indexed userId,
        ActivityType activityType,
        uint256 valueScore,
        bytes32 dataHash
    );
    event ActivityRewarded(
        bytes32 indexed activityId,
        bytes32 indexed userId,
        uint256 mineAmount,
        uint256 valueScore
    );
    event DailyCapReached(bytes32 indexed userId, uint256 day, uint256 cappedAmount);
    
    constructor(address _tokenEngine, address _identityRegistry) {
        require(_tokenEngine != address(0), "Invalid TokenEngine address");
        require(_identityRegistry != address(0), "Invalid IdentityRegistry address");
        
        tokenEngine = TokenEngine(_tokenEngine);
        identityRegistry = IdentityRegistry(_identityRegistry);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        
        // Set default base value scores
        baseValueScores[ActivityType.BiometricStream] = 5;
        baseValueScores[ActivityType.TherapyCompletion] = 20;
        baseValueScores[ActivityType.DataValidation] = 15;
        baseValueScores[ActivityType.Referral] = 25;
        baseValueScores[ActivityType.SurveyCompletion] = 10;
        baseValueScores[ActivityType.PreventiveCare] = 30;
    }
    
    /**
     * @dev Record activity with validation
     * @param activityId Unique identifier for this activity
     * @param userId Hashed user identifier
     * @param activityType Type of activity performed
     * @param dataHash IPFS hash of detailed activity data
     * @param valueScore Calculated value score (1-100)
     * @param userAddress Address to receive MINE tokens
     */
    function recordActivity(
        bytes32 activityId,
        bytes32 userId,
        ActivityType activityType,
        bytes32 dataHash,
        uint256 valueScore,
        address userAddress
    ) external onlyRole(ORACLE_ROLE) nonReentrant returns (bool) {
        require(activityProofs[activityId].timestamp == 0, "Activity already recorded");
        require(valueScore > 0 && valueScore <= 100, "Invalid value score");
        require(userAddress != address(0), "Invalid user address");
        
        // Check rate limit
        uint256 day = block.timestamp / DAY_IN_SECONDS;
        bytes32 dailyKey = keccak256(abi.encodePacked(userId, day));
        uint256 currentDailyPoints = dailyPoints[dailyKey];
        
        uint256 actualValueScore = valueScore;
        if (currentDailyPoints + valueScore > DAILY_POINTS_CAP) {
            actualValueScore = DAILY_POINTS_CAP - currentDailyPoints;
            emit DailyCapReached(userId, day, actualValueScore);
        }
        
        // Store activity proof
        activityProofs[activityId] = ActivityProof({
            userId: userId,
            activityType: activityType,
            timestamp: block.timestamp,
            dataHash: dataHash,
            valueScore: actualValueScore,
            validator: msg.sender,
            rewarded: actualValueScore > 0
        });
        
        allActivityIds.push(activityId);
        activityTypeCount[activityType]++;
        
        // Update daily points
        dailyPoints[dailyKey] = currentDailyPoints + actualValueScore;
        totalUserPoints[userId] += actualValueScore;
        
        emit ActivityRecorded(activityId, userId, activityType, actualValueScore, dataHash);
        
        // Mint MINE if value score > 0
        if (actualValueScore > 0) {
            uint256 mineAmount = tokenEngine.mineActivity(userAddress, actualValueScore);
            emit ActivityRewarded(activityId, userId, mineAmount, actualValueScore);
        }
        
        return true;
    }
    
    /**
     * @dev Batch record activities (gas efficient for oracle)
     * Simplified to avoid stack too deep
     */
    function batchRecordActivities(
        bytes32[] calldata activityIds,
        bytes32[] calldata userIds,
        ActivityType[] calldata activityTypes,
        bytes32[] calldata dataHashes,
        uint256[] calldata valueScores,
        address[] calldata userAddresses
    ) external onlyRole(ORACLE_ROLE) nonReentrant returns (uint256 rewardedCount) {
        uint256 len = activityIds.length;
        require(len == userIds.length && len == activityTypes.length, "Length mismatch");
        require(len == dataHashes.length && len == valueScores.length && len == userAddresses.length, "Length mismatch");
        
        uint256 day = block.timestamp / DAY_IN_SECONDS;
        
        for (uint i = 0; i < len; i++) {
            _processBatchActivity(
                activityIds[i],
                userIds[i],
                activityTypes[i],
                dataHashes[i],
                valueScores[i],
                userAddresses[i],
                day
            );
            rewardedCount++;
        }
    }
    
    function _processBatchActivity(
        bytes32 activityId,
        bytes32 userId,
        ActivityType activityType,
        bytes32 dataHash,
        uint256 valueScore,
        address userAddress,
        uint256 day
    ) internal {
        if (activityProofs[activityId].timestamp != 0) return; // Skip duplicates
        
        bytes32 dailyKey = keccak256(abi.encodePacked(userId, day));
        uint256 currentDailyPoints = dailyPoints[dailyKey];
        
        if (valueScore > 100) valueScore = 100;
        
        if (currentDailyPoints + valueScore > DAILY_POINTS_CAP) {
            valueScore = DAILY_POINTS_CAP > currentDailyPoints 
                ? DAILY_POINTS_CAP - currentDailyPoints 
                : 0;
        }
        
        activityProofs[activityId] = ActivityProof({
            userId: userId,
            activityType: activityType,
            timestamp: block.timestamp,
            dataHash: dataHash,
            valueScore: valueScore,
            validator: msg.sender,
            rewarded: valueScore > 0
        });
        
        allActivityIds.push(activityId);
        activityTypeCount[activityType]++;
        dailyPoints[dailyKey] = currentDailyPoints + valueScore;
        totalUserPoints[userId] += valueScore;
        
        emit ActivityRecorded(activityId, userId, activityType, valueScore, dataHash);
        
        if (valueScore > 0) {
            tokenEngine.mineActivity(userAddress, valueScore);
            emit ActivityRewarded(activityId, userId, valueScore * 10 * 10**18, valueScore);
        }
    }
    
    /**
     * @dev Verify activity proof exists and is valid
     */
    function verifyActivity(bytes32 activityId) external view returns (
        bool exists,
        ActivityProof memory proof
    ) {
        proof = activityProofs[activityId];
        exists = proof.timestamp != 0;
    }
    
    /**
     * @dev Get user's daily points usage
     */
    function getDailyPoints(bytes32 userId, uint256 day) external view returns (uint256) {
        bytes32 dailyKey = keccak256(abi.encodePacked(userId, day));
        return dailyPoints[dailyKey];
    }
    
    /**
     * @dev Get today's remaining points for user
     */
    function getRemainingDailyPoints(bytes32 userId) external view returns (uint256) {
        uint256 day = block.timestamp / DAY_IN_SECONDS;
        bytes32 dailyKey = keccak256(abi.encodePacked(userId, day));
        uint256 used = dailyPoints[dailyKey];
        return used >= DAILY_POINTS_CAP ? 0 : DAILY_POINTS_CAP - used;
    }
    
    /**
     * @dev Get activity count for type
     */
    function getActivityCount(ActivityType activityType) external view returns (uint256) {
        return activityTypeCount[activityType];
    }
    
    /**
     * @dev Get total activities recorded
     */
    function getTotalActivities() external view returns (uint256) {
        return allActivityIds.length;
    }
    
    /**
     * @dev Get activities page (for UI)
     */
    function getActivitiesPage(uint256 start, uint256 count) external view returns (
        bytes32[] memory ids,
        ActivityProof[] memory proofs
    ) {
        uint256 end = start + count;
        if (end > allActivityIds.length) end = allActivityIds.length;
        
        uint256 actualCount = end > start ? end - start : 0;
        ids = new bytes32[](actualCount);
        proofs = new ActivityProof[](actualCount);
        
        for (uint i = 0; i < actualCount; i++) {
            ids[i] = allActivityIds[start + i];
            proofs[i] = activityProofs[ids[i]];
        }
    }
    
    /**
     * @dev Update base value score for activity type
     */
    function setBaseValueScore(ActivityType activityType, uint256 score) external onlyRole(ADMIN_ROLE) {
        require(score <= 100, "Score too high");
        baseValueScores[activityType] = score;
    }
    
    /**
     * @dev Check if user can earn points today
     */
    function canEarnPoints(bytes32 userId, uint256 requestedPoints) external view returns (bool) {
        uint256 day = block.timestamp / DAY_IN_SECONDS;
        bytes32 dailyKey = keccak256(abi.encodePacked(userId, day));
        return dailyPoints[dailyKey] + requestedPoints <= DAILY_POINTS_CAP;
    }
}
