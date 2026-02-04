// SPDX-License-Identifier: MIT
/**
 * @title AuditTrail
 * @notice Append-only, Nightingale-indexed immutable event log
 * 
 * INSPIRED BY:
 * - Pillar 3 (Reverse-Engineer Genius): Satoshi's immutable logs, Nightingale's data precision
 * - Pillar 4 (Strategic Dominance): Zero central liability via append-only architecture
 * - Pillar 6 (Forbidden Frameworks): OODA loop circuit breakers for anomaly detection
 * 
 * ARCHITECTURE:
 * - Append-only: Events can never be deleted or modified
 * - Nightingale indexing: Optimized for time-series and categorical queries
 * - Merkle mountain range for cryptographic verification
 * - OODA circuit breakers for real-time anomaly detection
 */
pragma solidity ^0.8.24;

import {LibDiamond} from "../libraries/LibDiamond.sol";

/**
 * @notice AuditTrail Diamond Storage
 */
library AuditTrailStorage {
    bytes32 constant STORAGE_POSITION = keccak256("terracare.audittrail.storage");
    
    // Action types for categorical indexing (Nightingale method)
    enum ActionType {
        IdentityCreated,
        IdentityUpdated,
        AccessGranted,
        AccessRevoked,
        AccessUsed,
        RecordCreated,
        RecordRead,
        RecordUpdated,
        RecordDeleted,
        SystemBinding,
        EmergencyOverride,
        BreakGlassActivated,
        BreakGlassDeactivated,
        CredentialIssued,
        StealthAddressUsed,
        ConsensusVote,
        AIInference,
        GeoFenceTriggered,
        FrequencyProtocol,
        DeviceCertified
    }
    
    // Severity levels for OODA circuit breakers
    enum Severity {
        Info,       // 0 - Normal operation
        Warning,    // 1 - Unusual pattern
        Alert,      // 2 - Potential issue
        Critical,   // 3 - Immediate attention
        Emergency   // 4 - Auto-circuit break
    }
    
    struct AuditEntry {
        uint256 index;              // Global sequence number
        uint256 timestamp;
        ActionType actionType;
        Severity severity;
        address actor;
        bytes32 subjectHash;        // Hash of affected entity (no PHI)
        bytes32 actionHash;         // Hash of action details
        bytes32 dataHash;           // Hash of associated data
        bytes32 previousHash;       // Chain for tamper evidence
        uint256 blockNumber;
    }
    
    // OODA Circuit Breaker state
    struct CircuitBreaker {
        bool isOpen;
        uint256 triggerTimestamp;
        Severity triggerLevel;
        bytes32 triggerReason;
        uint256 consecutiveAlerts;
    }
    
    struct Storage {
        // Append-only log
        AuditEntry[] entries;
        uint256 totalEntries;
        
        // Nightingale indexing: ActionType -> entry indices
        mapping(ActionType => uint256[]) actionTypeIndex;
        
        // Nightingale indexing: Actor -> entry indices
        mapping(address => uint256[]) actorIndex;
        
        // Nightingale indexing: Time buckets (hourly)
        mapping(uint256 => uint256[]) timeIndex;
        
        // Severity tracking for OODA
        mapping(Severity => uint256) severityCounts;
        
        // OODA Circuit breakers per action type
        mapping(ActionType => CircuitBreaker) circuitBreakers;
        
        // Anomaly detection thresholds
        mapping(ActionType => uint256) alertThresholds;
        mapping(ActionType => uint256) criticalThresholds;
        
        // Merkle mountain range peaks
        bytes32[] mountainPeaks;
        
        // ERC-2771
        mapping(address => bool) trustedForwarders;
        
        // Frozen state (scorched earth)
        bool isFrozen;
    }
    
    function getStorage() internal pure returns (Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}

/**
 * @notice Events for Heartware indexing
 */
interface IAuditTrailEvents {
    event AuditEntryCreated(
        uint256 indexed index,
        AuditTrailStorage.ActionType indexed actionType,
        AuditTrailStorage.Severity indexed severity,
        address actor,
        bytes32 subjectHash,
        bytes32 actionHash,
        uint256 timestamp
    );
    
    event CircuitBreakerOpened(
        AuditTrailStorage.ActionType indexed actionType,
        AuditTrailStorage.Severity triggerLevel,
        bytes32 triggerReason,
        uint256 timestamp
    );
    
    event CircuitBreakerClosed(
        AuditTrailStorage.ActionType indexed actionType,
        uint256 timestamp
    );
    
    event AuditLogFrozen(
        address indexed triggeredBy,
        bytes32 reason,
        uint256 timestamp
    );
    
    event MountainPeakAdded(
        uint256 indexed peakIndex,
        bytes32 indexed peakHash,
        uint256 timestamp
    );
}

/**
 * @title AuditTrail Facet
 * @notice Diamond facet for immutable audit logging
 */
contract AuditTrail is IAuditTrailEvents {
    
    // OODA thresholds
    uint256 constant OODA_ALERT_CONSECUTIVE = 10;
    uint256 constant OODA_CRITICAL_CONSECUTIVE = 5;
    uint256 constant OODA_EMERGENCY_CONSECUTIVE = 3;
    uint256 constant CIRCUIT_BREAKER_COOLDOWN = 1 hours;
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }
    
    modifier notFrozen() {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        require(!s.isFrozen, "AuditTrail: System frozen");
        _;
    }
    
    modifier circuitNotOpen(AuditTrailStorage.ActionType _actionType) {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        require(
            !s.circuitBreakers[_actionType].isOpen || 
            block.timestamp > s.circuitBreakers[_actionType].triggerTimestamp + CIRCUIT_BREAKER_COOLDOWN,
            "AuditTrail: Circuit breaker open"
        );
        _;
    }
    
    // ============ ERC-2771 Support ============
    
    function _msgSender() internal view returns (address) {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        uint256 calldataLength = msg.data.length;
        
        if (calldataLength >= 20 && s.trustedForwarders[msg.sender]) {
            address sender;
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
            return sender;
        }
        return msg.sender;
    }
    
    // ============ Core Audit Functions ============
    
    /**
     * @notice Create audit entry (append-only)
     * @param _actionType Type of action being logged
     * @param _severity Severity level
     * @param _subjectHash Hash of affected entity
     * @param _actionHash Hash of action details
     * @param _dataHash Hash of associated data
     * @return index The entry index
     * 
     * INSPIRED BY: Satoshi's immutable blockchain - chain of hashes
     */
    function createEntry(
        AuditTrailStorage.ActionType _actionType,
        AuditTrailStorage.Severity _severity,
        bytes32 _subjectHash,
        bytes32 _actionHash,
        bytes32 _dataHash
    ) external notFrozen circuitNotOpen(_actionType) returns (uint256 index) {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        
        index = s.entries.length;
        
        bytes32 previousHash = index > 0 
            ? keccak256(abi.encode(s.entries[index - 1])) 
            : bytes32(0);
        
        AuditTrailStorage.AuditEntry memory entry = AuditTrailStorage.AuditEntry({
            index: index,
            timestamp: block.timestamp,
            actionType: _actionType,
            severity: _severity,
            actor: _msgSender(),
            subjectHash: _subjectHash,
            actionHash: _actionHash,
            dataHash: _dataHash,
            previousHash: previousHash,
            blockNumber: block.number
        });
        
        s.entries.push(entry);
        s.totalEntries++;
        
        // Nightingale indexing
        s.actionTypeIndex[_actionType].push(index);
        s.actorIndex[_msgSender()].push(index);
        s.timeIndex[block.timestamp / 3600].push(index);
        s.severityCounts[_severity]++;
        
        emit AuditEntryCreated(
            index,
            _actionType,
            _severity,
            _msgSender(),
            _subjectHash,
            _actionHash,
            block.timestamp
        );
        
        // OODA Circuit breaker check
        _checkOODA(_actionType, _severity);
        
        // Merkle mountain range update (every 1024 entries)
        if (index > 0 && index % 1024 == 0) {
            _addMountainPeak(index);
        }
        
        return index;
    }
    
    /**
     * @notice Batch create entries (gas efficient)
     */
    function createBatch(
        AuditTrailStorage.ActionType[] calldata _actionTypes,
        AuditTrailStorage.Severity[] calldata _severities,
        bytes32[] calldata _subjectHashes,
        bytes32[] calldata _actionHashes,
        bytes32[] calldata _dataHashes
    ) external notFrozen returns (uint256[] memory indices) {
        require(
            _actionTypes.length == _severities.length &&
            _actionTypes.length == _subjectHashes.length &&
            _actionTypes.length == _actionHashes.length &&
            _actionTypes.length == _dataHashes.length,
            "AuditTrail: Array length mismatch"
        );
        
        indices = new uint256[](_actionTypes.length);
        
        for (uint256 i = 0; i < _actionTypes.length; i++) {
            // Use low-level call to avoid stack too deep
            indices[i] = this.createEntry(
                _actionTypes[i],
                _severities[i],
                _subjectHashes[i],
                _actionHashes[i],
                _dataHashes[i]
            );
        }
        
        return indices;
    }
    
    // ============ OODA Circuit Breakers ============
    
    /**
     * @notice OODA loop: Observe-Orient-Decide-Act
     * @dev Monitors consecutive alerts and opens circuit if thresholds exceeded
     */
    function _checkOODA(
        AuditTrailStorage.ActionType _actionType,
        AuditTrailStorage.Severity _severity
    ) internal {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        AuditTrailStorage.CircuitBreaker storage cb = s.circuitBreakers[_actionType];
        
        if (_severity == AuditTrailStorage.Severity.Info) {
            cb.consecutiveAlerts = 0;
            return;
        }
        
        cb.consecutiveAlerts++;
        
        uint256 threshold;
        if (_severity == AuditTrailStorage.Severity.Warning) {
            threshold = OODA_ALERT_CONSECUTIVE * 2;
        } else if (_severity == AuditTrailStorage.Severity.Alert) {
            threshold = OODA_ALERT_CONSECUTIVE;
        } else if (_severity == AuditTrailStorage.Severity.Critical) {
            threshold = OODA_CRITICAL_CONSECUTIVE;
        } else if (_severity == AuditTrailStorage.Severity.Emergency) {
            threshold = OODA_EMERGENCY_CONSECUTIVE;
        }
        
        if (cb.consecutiveAlerts >= threshold && !cb.isOpen) {
            cb.isOpen = true;
            cb.triggerTimestamp = block.timestamp;
            cb.triggerLevel = _severity;
            cb.triggerReason = keccak256(abi.encodePacked("OODA threshold exceeded"));
            
            emit CircuitBreakerOpened(
                _actionType,
                _severity,
                cb.triggerReason,
                block.timestamp
            );
        }
    }
    
    /**
     * @notice Close circuit breaker (manual override)
     */
    function closeCircuitBreaker(AuditTrailStorage.ActionType _actionType) external onlyOwner {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        AuditTrailStorage.CircuitBreaker storage cb = s.circuitBreakers[_actionType];
        
        require(cb.isOpen, "AuditTrail: Circuit not open");
        
        cb.isOpen = false;
        cb.consecutiveAlerts = 0;
        
        emit CircuitBreakerClosed(_actionType, block.timestamp);
    }
    
    /**
     * @notice Set OODA thresholds
     */
    function setOODAThresholds(
        AuditTrailStorage.ActionType _actionType,
        uint256 _alertThreshold,
        uint256 _criticalThreshold
    ) external onlyOwner {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        s.alertThresholds[_actionType] = _alertThreshold;
        s.criticalThresholds[_actionType] = _criticalThreshold;
    }
    
    // ============ Merkle Mountain Range ============
    
    /**
     * @notice Add mountain peak for cryptographic verification
     */
    function _addMountainPeak(uint256 _entryIndex) internal {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        
        // Calculate peak from last 1024 entries
        uint256 startIdx = _entryIndex - 1024;
        bytes32 peakHash = keccak256(abi.encode(s.entries[startIdx]));
        
        for (uint256 i = startIdx + 1; i < _entryIndex && i < s.entries.length; i++) {
            peakHash = keccak256(abi.encodePacked(peakHash, keccak256(abi.encode(s.entries[i]))));
        }
        
        uint256 peakIndex = s.mountainPeaks.length;
        s.mountainPeaks.push(peakHash);
        
        emit MountainPeakAdded(peakIndex, peakHash, block.timestamp);
    }
    
    /**
     * @notice Get mountain peak for verification
     */
    function getMountainPeak(uint256 _peakIndex) external view returns (bytes32) {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        require(_peakIndex < s.mountainPeaks.length, "AuditTrail: Invalid peak");
        return s.mountainPeaks[_peakIndex];
    }
    
    /**
     * @notice Verify entry exists in log (proof of existence)
     */
    function verifyEntry(
        uint256 _index,
        bytes32 _expectedHash
    ) external view returns (bool) {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        if (_index >= s.entries.length) return false;
        
        bytes32 computedHash = keccak256(abi.encode(s.entries[_index]));
        return computedHash == _expectedHash;
    }
    
    // ============ Scorched Earth Mode ============
    
    /**
     * @notice Freeze audit log permanently (scorched earth)
     * @dev Only in extreme emergency - prevents ALL new entries
     */
    function freezeAuditLog(bytes32 _reason) external onlyOwner {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        s.isFrozen = true;
        
        emit AuditLogFrozen(_msgSender(), _reason, block.timestamp);
    }
    
    function isFrozen() external view returns (bool) {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        return s.isFrozen;
    }
    
    // ============ Nightingale Index Queries ============
    
    /**
     * @notice Get entries by action type
     */
    function getEntriesByActionType(
        AuditTrailStorage.ActionType _actionType,
        uint256 _start,
        uint256 _limit
    ) external view returns (AuditTrailStorage.AuditEntry[] memory) {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        uint256[] storage indices = s.actionTypeIndex[_actionType];
        
        uint256 end = _start + _limit;
        if (end > indices.length) end = indices.length;
        if (_start >= indices.length) return new AuditTrailStorage.AuditEntry[](0);
        
        AuditTrailStorage.AuditEntry[] memory result = new AuditTrailStorage.AuditEntry[](end - _start);
        
        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = s.entries[indices[i]];
        }
        
        return result;
    }
    
    /**
     * @notice Get entries by actor
     */
    function getEntriesByActor(
        address _actor,
        uint256 _start,
        uint256 _limit
    ) external view returns (AuditTrailStorage.AuditEntry[] memory) {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        uint256[] storage indices = s.actorIndex[_actor];
        
        uint256 end = _start + _limit;
        if (end > indices.length) end = indices.length;
        if (_start >= indices.length) return new AuditTrailStorage.AuditEntry[](0);
        
        AuditTrailStorage.AuditEntry[] memory result = new AuditTrailStorage.AuditEntry[](end - _start);
        
        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = s.entries[indices[i]];
        }
        
        return result;
    }
    
    /**
     * @notice Get entry count
     */
    function getEntryCount() external view returns (uint256) {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        return s.entries.length;
    }
    
    /**
     * @notice Get entry by index
     */
    function getEntry(uint256 _index) external view returns (AuditTrailStorage.AuditEntry memory) {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        require(_index < s.entries.length, "AuditTrail: Invalid index");
        return s.entries[_index];
    }
    
    /**
     * @notice Get severity counts for monitoring
     */
    function getSeverityCounts() external view returns (
        uint256 info,
        uint256 warning,
        uint256 alert,
        uint256 critical,
        uint256 emergency
    ) {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        return (
            s.severityCounts[AuditTrailStorage.Severity.Info],
            s.severityCounts[AuditTrailStorage.Severity.Warning],
            s.severityCounts[AuditTrailStorage.Severity.Alert],
            s.severityCounts[AuditTrailStorage.Severity.Critical],
            s.severityCounts[AuditTrailStorage.Severity.Emergency]
        );
    }
    
    // ============ Admin Functions ============
    
    function setTrustedForwarder(address _forwarder, bool _trusted) external onlyOwner {
        AuditTrailStorage.Storage storage s = AuditTrailStorage.getStorage();
        s.trustedForwarders[_forwarder] = _trusted;
    }
}
