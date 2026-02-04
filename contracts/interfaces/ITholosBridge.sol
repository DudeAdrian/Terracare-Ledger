// SPDX-License-Identifier: MIT
/**
 * @title ITholosBridge
 * @notice Interface for Tholos clinical records bridge
 * @dev Connects Terracare Ledger to Tholos clinical record system
 */
pragma solidity ^0.8.24;

interface ITholosBridge {
    /// @notice Record types supported by Tholos
    enum RecordType {
        Consultation,
        Diagnosis,
        Treatment,
        LabResult,
        Imaging,
        Prescription,
        Allergy,
        Immunization
    }

    /// @notice Structure for clinical record metadata (hash-only)
    struct ClinicalRecord {
        bytes32 recordHash;         // IPFS/Arweave hash of encrypted record
        bytes32 patientIdentity;    // Sovereign identity hash
        RecordType recordType;
        address provider;           // Authorized healthcare provider
        uint256 timestamp;
        bool isActive;
    }

    /// @notice Emitted when a clinical record is registered
    event ClinicalRecordRegistered(
        bytes32 indexed recordHash,
        bytes32 indexed patientIdentity,
        RecordType recordType,
        address indexed provider,
        uint256 timestamp
    );

    /// @notice Emitted when a record access is logged
    event RecordAccessLogged(
        bytes32 indexed recordHash,
        address indexed accessor,
        bytes32 actionHash,
        uint256 timestamp
    );

    /// @notice Register a new clinical record
    /// @param _recordHash Hash pointer to off-chain encrypted data
    /// @param _patientIdentity Patient's sovereign identity hash
    /// @param _recordType Type of clinical record
    function registerClinicalRecord(
        bytes32 _recordHash,
        bytes32 _patientIdentity,
        RecordType _recordType
    ) external returns (bool);

    /// @notice Verify record exists and is accessible
    /// @param _recordHash The record hash to verify
    /// @param _accessor Address requesting access
    function verifyRecordAccess(
        bytes32 _recordHash,
        address _accessor
    ) external view returns (bool hasAccess, uint256 timestamp);

    /// @notice Get record metadata (no PHI)
    /// @param _recordHash The record hash
    function getRecordMetadata(
        bytes32 _recordHash
    ) external view returns (ClinicalRecord memory);

    /// @notice Get all records for a patient (hash list only)
    /// @param _patientIdentity Patient's identity hash
    function getPatientRecords(
        bytes32 _patientIdentity
    ) external view returns (bytes32[] memory recordHashes);
}
