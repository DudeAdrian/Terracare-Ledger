// SPDX-License-Identifier: MIT
/**
 * @title TholosAdapter
 * @notice Bridge between Terracare Ledger and Tholos Clinical Records
 * @dev Implements ITholosBridge for hash-only clinical record management
 */
pragma solidity ^0.8.24;

import {ITholosBridge} from "../interfaces/ITholosBridge.sol";

contract TholosAdapter is ITholosBridge {
    
    // ============ Storage ============
    
    address public sovereignIdentity;
    address public accessGovernor;
    address public auditTrail;
    
    // Patient identity hash => record hashes
    mapping(bytes32 => bytes32[]) private patientRecords;
    
    // Record hash => record data
    mapping(bytes32 => ClinicalRecord) private records;
    
    // Record hash => authorized accessors
    mapping(bytes32 => mapping(address => bool)) private recordAccess;
    
    // Provider => isAuthorized
    mapping(address => bool) public authorizedProviders;
    
    // ============ Modifiers ============
    
    modifier onlyAuthorizedProvider() {
        require(authorizedProviders[msg.sender], "TholosAdapter: Not authorized provider");
        _;
    }
    
    modifier onlySovereignIdentity() {
        require(msg.sender == sovereignIdentity, "TholosAdapter: Not sovereign identity");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(
        address _sovereignIdentity,
        address _accessGovernor,
        address _auditTrail
    ) {
        sovereignIdentity = _sovereignIdentity;
        accessGovernor = _accessGovernor;
        auditTrail = _auditTrail;
    }
    
    // ============ Admin Functions ============
    
    function authorizeProvider(address provider) external {
        // Only callable by AccessGovernor or SovereignIdentity
        require(
            msg.sender == accessGovernor || msg.sender == sovereignIdentity,
            "TholosAdapter: Not authorized"
        );
        authorizedProviders[provider] = true;
    }
    
    function revokeProvider(address provider) external {
        require(
            msg.sender == accessGovernor || msg.sender == sovereignIdentity,
            "TholosAdapter: Not authorized"
        );
        authorizedProviders[provider] = false;
    }
    
    // ============ ITholosBridge Implementation ============
    
    function registerClinicalRecord(
        bytes32 _recordHash,
        bytes32 _patientIdentity,
        RecordType _recordType
    ) external override onlyAuthorizedProvider returns (bool) {
        require(_recordHash != bytes32(0), "TholosAdapter: Invalid record hash");
        require(_patientIdentity != bytes32(0), "TholosAdapter: Invalid patient identity");
        require(records[_recordHash].recordHash == bytes32(0), "TholosAdapter: Record exists");
        
        ClinicalRecord memory record = ClinicalRecord({
            recordHash: _recordHash,
            patientIdentity: _patientIdentity,
            recordType: _recordType,
            provider: msg.sender,
            timestamp: block.timestamp,
            isActive: true
        });
        
        records[_recordHash] = record;
        patientRecords[_patientIdentity].push(_recordHash);
        recordAccess[_recordHash][msg.sender] = true;
        
        emit ClinicalRecordRegistered(
            _recordHash,
            _patientIdentity,
            _recordType,
            msg.sender,
            block.timestamp
        );
        
        return true;
    }
    
    function verifyRecordAccess(
        bytes32 _recordHash,
        address _accessor
    ) external view override returns (bool hasAccess, uint256 timestamp) {
        ClinicalRecord storage record = records[_recordHash];
        if (record.recordHash == bytes32(0)) return (false, 0);
        if (!record.isActive) return (false, 0);
        
        // Provider always has access
        if (record.provider == _accessor) return (true, record.timestamp);
        
        // Check authorized access
        if (recordAccess[_recordHash][_accessor]) return (true, record.timestamp);
        
        return (false, 0);
    }
    
    function getRecordMetadata(
        bytes32 _recordHash
    ) external view override returns (ClinicalRecord memory) {
        return records[_recordHash];
    }
    
    function getPatientRecords(
        bytes32 _patientIdentity
    ) external view override returns (bytes32[] memory recordHashes) {
        return patientRecords[_patientIdentity];
    }
    
    // ============ Additional Functions ============
    
    function grantRecordAccess(
        bytes32 _recordHash,
        address _accessor
    ) external onlyAuthorizedProvider {
        ClinicalRecord storage record = records[_recordHash];
        require(record.provider == msg.sender, "TholosAdapter: Not record owner");
        recordAccess[_recordHash][_accessor] = true;
    }
    
    function revokeRecordAccess(
        bytes32 _recordHash,
        address _accessor
    ) external onlyAuthorizedProvider {
        ClinicalRecord storage record = records[_recordHash];
        require(record.provider == msg.sender, "TholosAdapter: Not record owner");
        recordAccess[_recordHash][_accessor] = false;
    }
    
    function deactivateRecord(bytes32 _recordHash) external onlyAuthorizedProvider {
        ClinicalRecord storage record = records[_recordHash];
        require(record.provider == msg.sender, "TholosAdapter: Not record owner");
        record.isActive = false;
    }
}
