// SPDX-License-Identifier: MIT
/**
 * @title TholosAdapter
 * @notice Clinical records integration with emergency override and break-glass
 * 
 * INSPIRED BY:
 * - Pillar 1 (Underground Knowledge): Commit-reveal for sensitive clinical data
 * - Pillar 3 (Reverse-Engineer Genius): Nightingale's data precision
 * - Pillar 5 (Black Market Tactics): Break-glass emergency access
 * 
 * ARCHITECTURE:
 * - Clinical record hashes only (zero PHI on-chain)
 * - Emergency override with audit trail
 * - Break-glass mode for life-threatening situations
 * - Integration with Tholos Medica clinical system
 */
pragma solidity ^0.8.24;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {SovereignIdentityStorage} from "../core/SovereignIdentity.sol";
import {AccessGovernorStorage} from "../core/AccessGovernor.sol";

/**
 * @notice TholosAdapter Diamond Storage
 */
library TholosAdapterStorage {
    bytes32 constant STORAGE_POSITION = keccak256("terracare.tholosadapter.storage");
    
    enum RecordType {
        Diagnosis,
        Treatment,
        Medication,
        LabResult,
        Imaging,
        Allergy,
        Immunization,
        Procedure,
        Encounter,
        Emergency
    }
    
    enum RecordStatus {
        Active,
        Updated,
        Corrected,
        Deleted,      // Soft delete with hash preserved
        Sealed        // Immutable after legal hold
    }
    
    struct ClinicalRecord {
        bytes32 recordHash;         // Hash of encrypted off-chain record
        bytes32 metadataHash;       // Hash of record metadata
        RecordType recordType;
        RecordStatus status;
        address provider;
        uint256 createdAt;
        uint256 updatedAt;
        uint256 version;            // For versioned records
        bytes32 previousVersion;    // Chain of custody
        bool isEmergency;           // Emergency record flag
    }
    
    struct Provider {
        bytes32 credentialHash;     // Soulbound credential reference
        bool isActive;
        bool canEmergency;
        uint256 registeredAt;
        bytes32 npiHash;           // National Provider Identifier hash
    }
    
    struct EmergencyAccess {
        address provider;
        bytes32 reasonHash;
        uint256 accessedAt;
        bytes32 recordHash;
        bool isBreakGlass;
    }
    
    struct Storage {
        // Patient -> Record ID -> Record
        mapping(address => mapping(bytes32 => ClinicalRecord)) records;
        
        // Patient record list (for enumeration)
        mapping(address => bytes32[]) patientRecords;
        
        // Registered providers
        mapping(address => Provider) providers;
        address[] providerList;
        
        // Emergency access log (patient -> provider -> access)
        mapping(address => mapping(address => EmergencyAccess)) emergencyAccess;
        mapping(address => address[]) patientEmergencyProviders;
        
        // Pending commits (commit-reveal pattern)
        mapping(bytes32 => bytes32) pendingCommits;
        mapping(bytes32 => uint256) commitTimestamps;
        
        // Record locks (for legal holds)
        mapping(bytes32 => bool) lockedRecords;
        
        // ERC-2771
        mapping(address => bool) trustedForwarders;
        
        // Audit trail reference
        address auditTrail;
        address sovereignIdentity;
        address accessGovernor;
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
interface ITholosAdapterEvents {
    event ClinicalRecordCreated(
        address indexed patient,
        bytes32 indexed recordId,
        bytes32 indexed recordHash,
        TholosAdapterStorage.RecordType recordType,
        address provider,
        uint256 timestamp
    );
    
    event ClinicalRecordUpdated(
        address indexed patient,
        bytes32 indexed recordId,
        bytes32 indexed newHash,
        uint256 version,
        uint256 timestamp
    );
    
    event ClinicalRecordSealed(
        address indexed patient,
        bytes32 indexed recordId,
        bytes32 reasonHash,
        uint256 timestamp
    );
    
    event ProviderRegistered(
        address indexed provider,
        bytes32 indexed credentialHash,
        bool canEmergency,
        uint256 timestamp
    );
    
    event EmergencyAccessGranted(
        address indexed patient,
        address indexed provider,
        bytes32 indexed reasonHash,
        bool isBreakGlass,
        uint256 timestamp
    );
    
    event EmergencyAccessRevoked(
        address indexed patient,
        address indexed provider,
        uint256 timestamp
    );
    
    event RecordCommitted(
        bytes32 indexed commitHash,
        uint256 revealDeadline,
        uint256 timestamp
    );
    
    event RecordRevealed(
        bytes32 indexed commitHash,
        bytes32 indexed recordId,
        address indexed provider,
        uint256 timestamp
    );
}

/**
 * @title TholosAdapter Facet
 * @notice Diamond facet for Tholos Medica clinical integration
 */
contract TholosAdapter is ITholosAdapterEvents {
    
    uint256 constant COMMIT_REVEAL_DELAY = 1 hours;
    uint256 constant EMERGENCY_ACCESS_DURATION = 24 hours;
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }
    
    modifier onlyRegisteredProvider() {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        require(s.providers[_msgSender()].isActive, "TholosAdapter: Not registered");
        _;
    }
    
    modifier validPatient(address _patient) {
        require(_patient != address(0), "TholosAdapter: Invalid patient");
        _;
    }
    
    // ============ ERC-2771 Support ============
    
    function _msgSender() internal view returns (address) {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
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
    
    // ============ Provider Management ============
    
    /**
     * @notice Register medical provider
     * @param _provider Provider address
     * @param _credentialHash Soulbound credential hash
     * @param _canEmergency Can access emergency records
     * @param _npiHash National Provider Identifier hash
     */
    function registerProvider(
        address _provider,
        bytes32 _credentialHash,
        bool _canEmergency,
        bytes32 _npiHash
    ) external onlyOwner {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        
        require(!s.providers[_provider].isActive, "TholosAdapter: Already registered");
        
        s.providers[_provider] = TholosAdapterStorage.Provider({
            credentialHash: _credentialHash,
            isActive: true,
            canEmergency: _canEmergency,
            registeredAt: block.timestamp,
            npiHash: _npiHash
        });
        
        s.providerList.push(_provider);
        
        emit ProviderRegistered(_provider, _credentialHash, _canEmergency, block.timestamp);
    }
    
    /**
     * @notice Deactivate provider
     */
    function deactivateProvider(address _provider) external onlyOwner {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        s.providers[_provider].isActive = false;
    }
    
    // ============ Clinical Records ============
    
    /**
     * @notice Create clinical record (hash only)
     * @param _patient Patient address
     * @param _recordId Unique record identifier
     * @param _recordHash Hash of encrypted off-chain record
     * @param _metadataHash Hash of record metadata
     * @param _recordType Type of clinical record
     */
    function createRecord(
        address _patient,
        bytes32 _recordId,
        bytes32 _recordHash,
        bytes32 _metadataHash,
        TholosAdapterStorage.RecordType _recordType
    ) external onlyRegisteredProvider validPatient(_patient) {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        address provider = _msgSender();
        
        require(
            s.records[_patient][_recordId].createdAt == 0,
            "TholosAdapter: Record exists"
        );
        
        s.records[_patient][_recordId] = TholosAdapterStorage.ClinicalRecord({
            recordHash: _recordHash,
            metadataHash: _metadataHash,
            recordType: _recordType,
            status: TholosAdapterStorage.RecordStatus.Active,
            provider: provider,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            version: 1,
            previousVersion: bytes32(0),
            isEmergency: false
        });
        
        s.patientRecords[_patient].push(_recordId);
        
        emit ClinicalRecordCreated(
            _patient,
            _recordId,
            _recordHash,
            _recordType,
            provider,
            block.timestamp
        );
    }
    
    /**
     * @notice Update clinical record (creates new version)
     */
    function updateRecord(
        address _patient,
        bytes32 _recordId,
        bytes32 _newRecordHash,
        bytes32 _newMetadataHash
    ) external onlyRegisteredProvider validPatient(_patient) {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        TholosAdapterStorage.ClinicalRecord storage record = s.records[_patient][_recordId];
        
        require(record.createdAt != 0, "TholosAdapter: Record not found");
        require(!s.lockedRecords[_recordId], "TholosAdapter: Record locked");
        require(
            record.provider == _msgSender() || 
            s.emergencyAccess[_patient][_msgSender()].accessedAt != 0,
            "TholosAdapter: Not authorized"
        );
        
        bytes32 previousHash = record.recordHash;
        
        record.recordHash = _newRecordHash;
        record.metadataHash = _newMetadataHash;
        record.status = TholosAdapterStorage.RecordStatus.Updated;
        record.updatedAt = block.timestamp;
        record.version++;
        record.previousVersion = previousHash;
        
        emit ClinicalRecordUpdated(
            _patient,
            _recordId,
            _newRecordHash,
            record.version,
            block.timestamp
        );
    }
    
    /**
     * @notice Seal record (immutable, for legal holds)
     */
    function sealRecord(
        address _patient,
        bytes32 _recordId,
        bytes32 _reasonHash
    ) external onlyOwner validPatient(_patient) {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        TholosAdapterStorage.ClinicalRecord storage record = s.records[_patient][_recordId];
        
        require(record.createdAt != 0, "TholosAdapter: Record not found");
        
        record.status = TholosAdapterStorage.RecordStatus.Sealed;
        s.lockedRecords[_recordId] = true;
        
        emit ClinicalRecordSealed(_patient, _recordId, _reasonHash, block.timestamp);
    }
    
    // ============ Emergency Access ============
    
    /**
     * @notice Request emergency access to patient records
     * @param _patient Patient address
     * @param _reasonHash Hash of emergency reason documentation
     */
    function requestEmergencyAccess(
        address _patient,
        bytes32 _reasonHash
    ) external onlyRegisteredProvider validPatient(_patient) {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        address provider = _msgSender();
        
        require(s.providers[provider].canEmergency, "TholosAdapter: No emergency access");
        
        // Check if break-glass mode is active in AccessGovernor
        // (simplified - would check external contract in production)
        
        s.emergencyAccess[_patient][provider] = TholosAdapterStorage.EmergencyAccess({
            provider: provider,
            reasonHash: _reasonHash,
            accessedAt: block.timestamp,
            recordHash: bytes32(0),
            isBreakGlass: false
        });
        
        s.patientEmergencyProviders[_patient].push(provider);
        
        emit EmergencyAccessGranted(_patient, provider, _reasonHash, false, block.timestamp);
    }
    
    /**
     * @notice Request break-glass emergency access
     * @dev For life-threatening situations - bypasses normal authorization
     */
    function requestBreakGlassAccess(
        address _patient,
        bytes32 _reasonHash
    ) external onlyRegisteredProvider validPatient(_patient) {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        address provider = _msgSender();
        
        require(s.providers[provider].canEmergency, "TholosAdapter: No emergency access");
        
        s.emergencyAccess[_patient][provider] = TholosAdapterStorage.EmergencyAccess({
            provider: provider,
            reasonHash: _reasonHash,
            accessedAt: block.timestamp,
            recordHash: keccak256(abi.encodePacked("BREAK_GLASS")),
            isBreakGlass: true
        });
        
        s.patientEmergencyProviders[_patient].push(provider);
        
        emit EmergencyAccessGranted(_patient, provider, _reasonHash, true, block.timestamp);
    }
    
    /**
     * @notice Revoke emergency access
     */
    function revokeEmergencyAccess(address _patient, address _provider) external {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        
        require(
            _msgSender() == _patient || 
            LibDiamond.isContractOwner(_msgSender()),
            "TholosAdapter: Not authorized"
        );
        
        delete s.emergencyAccess[_patient][_provider];
        
        emit EmergencyAccessRevoked(_patient, _provider, block.timestamp);
    }
    
    /**
     * @notice Check if provider has valid emergency access
     */
    function hasEmergencyAccess(address _patient, address _provider) public view returns (bool) {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        TholosAdapterStorage.EmergencyAccess storage access = s.emergencyAccess[_patient][_provider];
        
        if (access.accessedAt == 0) return false;
        
        // Break-glass is permanent, normal emergency expires
        if (access.isBreakGlass) return true;
        
        return (block.timestamp - access.accessedAt) < EMERGENCY_ACCESS_DURATION;
    }
    
    // ============ Commit-Reveal Pattern ============
    
    /**
     * @notice Commit to creating a record (privacy-preserving)
     * @param _commitHash Hash of (recordId + recordHash + secret)
     */
    function commitRecord(bytes32 _commitHash) external onlyRegisteredProvider {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        
        require(s.pendingCommits[_commitHash] == bytes32(0), "TholosAdapter: Commit exists");
        
        s.pendingCommits[_commitHash] = keccak256(abi.encodePacked(_msgSender()));
        s.commitTimestamps[_commitHash] = block.timestamp;
        
        emit RecordCommitted(_commitHash, block.timestamp + COMMIT_REVEAL_DELAY, block.timestamp);
    }
    
    /**
     * @notice Reveal and create committed record
     */
    function revealRecord(
        bytes32 _commitHash,
        address _patient,
        bytes32 _recordId,
        bytes32 _recordHash,
        bytes32 _metadataHash,
        TholosAdapterStorage.RecordType _recordType,
        bytes32 _secret
    ) external onlyRegisteredProvider {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        
        require(s.pendingCommits[_commitHash] != bytes32(0), "TholosAdapter: Commit not found");
        require(
            block.timestamp >= s.commitTimestamps[_commitHash] + COMMIT_REVEAL_DELAY,
            "TholosAdapter: Reveal too early"
        );
        
        // Verify commitment
        bytes32 verificationHash = keccak256(abi.encodePacked(_recordId, _recordHash, _secret));
        require(verificationHash == _commitHash, "TholosAdapter: Invalid reveal");
        
        // Create record
        s.records[_patient][_recordId] = TholosAdapterStorage.ClinicalRecord({
            recordHash: _recordHash,
            metadataHash: _metadataHash,
            recordType: _recordType,
            status: TholosAdapterStorage.RecordStatus.Active,
            provider: _msgSender(),
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            version: 1,
            previousVersion: bytes32(0),
            isEmergency: false
        });
        
        s.patientRecords[_patient].push(_recordId);
        
        delete s.pendingCommits[_commitHash];
        delete s.commitTimestamps[_commitHash];
        
        emit RecordRevealed(_commitHash, _recordId, _msgSender(), block.timestamp);
        emit ClinicalRecordCreated(
            _patient,
            _recordId,
            _recordHash,
            _recordType,
            _msgSender(),
            block.timestamp
        );
    }
    
    // ============ View Functions ============
    
    function getRecord(
        address _patient,
        bytes32 _recordId
    ) external view returns (TholosAdapterStorage.ClinicalRecord memory) {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        return s.records[_patient][_recordId];
    }
    
    function getPatientRecords(address _patient) external view returns (bytes32[] memory) {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        return s.patientRecords[_patient];
    }
    
    function getProvider(address _provider) external view returns (TholosAdapterStorage.Provider memory) {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        return s.providers[_provider];
    }
    
    // ============ Admin Functions ============
    
    function setContractAddresses(
        address _auditTrail,
        address _sovereignIdentity,
        address _accessGovernor
    ) external onlyOwner {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        s.auditTrail = _auditTrail;
        s.sovereignIdentity = _sovereignIdentity;
        s.accessGovernor = _accessGovernor;
    }
    
    function setTrustedForwarder(address _forwarder, bool _trusted) external onlyOwner {
        TholosAdapterStorage.Storage storage s = TholosAdapterStorage.getStorage();
        s.trustedForwarders[_forwarder] = _trusted;
    }
}
