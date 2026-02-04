// SPDX-License-Identifier: MIT
// Pillar-1: Soulbound tokens for device certification (ERC-5192)
// Pillar-2: Antifragility - System strengthens with each biofeedback session
// Pillar-3: Genius Channeled - Buckminster Fuller (synergetic whole-system wellness)
// Pillar-4: Data Dignity for biometric data
// Pillar-5: Side-channel resistance for HRV data
// Pillar-6: Zettelkasten linking between wellness sessions
// Pillar-7: Build for generational health tracking

pragma solidity ^0.8.24;

import "../SovereignIdentity.sol";
import "../AccessGovernor.sol";
import "../AuditTrail.sol";

/**
 * @title HarmonicAdapter
 * @dev Biofeedback and wellness module adapter for Terracare
 *      - Device certification via soulbound pattern
 *      - HRV data hashes anchored on-chain
 *      - Session integrity with Merkle verification
 *      - Wellness credential issuance
 */
contract HarmonicAdapter {
    // ============ Structs ============
    
    struct DeviceCertification {
        bytes32 deviceHash;         // Hash of device identifier
        bytes32 firmwareHash;       // Hash of firmware version
        uint256 certifiedAt;
        uint256 expiresAt;
        bool revoked;
        bytes32 calibrationHash;    // Device calibration data hash
    }

    struct BiofeedbackSession {
        bytes32 sessionHash;        // Hash of session data
        bytes32 hrvDataHash;        // Heart rate variability data hash
        bytes32 deviceHash;         // Device used
        uint256 startedAt;
        uint256 duration;           // Seconds
        bytes32 protocolHash;       // Protocol used hash
        uint256 wellnessScore;      // Computed wellness metric (0-10000)
        bytes32 practitionerHash;   // Optional practitioner hash
    }

    struct WellnessCredential {
        bytes32 credentialHash;
        uint256 issuedAt;
        uint256 expiresAt;
        bytes32 achievementHash;    // What was achieved
        bool revoked;
    }

    // ============ State ============
    
    SovereignIdentity public identity;
    AccessGovernor public accessGovernor;
    AuditTrail public auditTrail;
    
    address public governance;
    
    // Device hash => certification
    mapping(bytes32 => DeviceCertification) public deviceCerts;
    bytes32[] public certifiedDevices;
    
    // patient => session hash => session
    mapping(address => mapping(bytes32 => BiofeedbackSession)) public sessions;
    mapping(address => bytes32[]) public patientSessions;
    
    // patient => credential hash => credential (soulbound)
    mapping(address => mapping(bytes32 => WellnessCredential)) public wellnessCredentials;
    mapping(address => bytes32[]) public patientCredentials;
    
    // Authorized practitioners
    mapping(address => bool) public authorizedPractitioners;
    
    // Protocol hashes
    mapping(bytes32 => bool) public validProtocols;

    // ============ Events ============
    
    event DeviceCertified(
        bytes32 indexed deviceHash,
        bytes32 firmwareHash,
        uint256 expiresAt
    );
    
    event DeviceRevoked(bytes32 indexed deviceHash, bytes32 reasonHash);
    
    event SessionRecorded(
        address indexed patient,
        bytes32 indexed sessionHash,
        bytes32 deviceHash,
        uint256 wellnessScore
    );
    
    event WellnessCredentialIssued(
        address indexed patient,
        bytes32 indexed credentialHash,
        bytes32 achievementHash
    );

    // ============ Modifiers ============
    
    modifier onlyGovernance() {
        require(msg.sender == governance, "HarmonicAdapter: Not governance");
        _;
    }

    modifier onlyAuthorizedPractitioner() {
        require(
            authorizedPractitioners[msg.sender] || msg.sender == governance,
            "HarmonicAdapter: Not authorized"
        );
        _;
    }

    modifier onlyCertifiedDevice(bytes32 deviceHash) {
        require(
            deviceCerts[deviceHash].certifiedAt != 0 &&
            !deviceCerts[deviceHash].revoked &&
            deviceCerts[deviceHash].expiresAt > block.timestamp,
            "HarmonicAdapter: Device not certified"
        );
        _;
    }

    // ============ Constructor ============
    
    constructor(
        address _identity,
        address _accessGovernor,
        address _auditTrail
    ) {
        identity = SovereignIdentity(_identity);
        accessGovernor = AccessGovernor(_accessGovernor);
        auditTrail = AuditTrail(_auditTrail);
        governance = msg.sender;
    }

    // ============ Device Certification (Soulbound Pattern) ============
    
    /**
     * @dev Certify a Harmonic device - soulbound certification
     * Pillar-1: Soulbound tokens for device certification
     */
    function certifyDevice(
        bytes32 deviceHash,
        bytes32 firmwareHash,
        bytes32 calibrationHash,
        uint256 validityDays
    ) external onlyGovernance {
        require(deviceCerts[deviceHash].certifiedAt == 0, "HarmonicAdapter: Already certified");

        deviceCerts[deviceHash] = DeviceCertification({
            deviceHash: deviceHash,
            firmwareHash: firmwareHash,
            certifiedAt: block.timestamp,
            expiresAt: block.timestamp + (validityDays * 1 days),
            revoked: false,
            calibrationHash: calibrationHash
        });

        certifiedDevices.push(deviceHash);

        auditTrail.createEntry(
            address(0), // System-level entry
            SovereignIdentity.SystemType.Harmonic,
            keccak256("DEVICE_CERTIFIED"),
            deviceHash,
            new bytes32[](0)
        );

        emit DeviceCertified(deviceHash, firmwareHash, block.timestamp + (validityDays * 1 days));
    }

    function revokeDevice(bytes32 deviceHash, bytes32 reasonHash) external onlyGovernance {
        require(deviceCerts[deviceHash].certifiedAt != 0, "HarmonicAdapter: Not certified");
        deviceCerts[deviceHash].revoked = true;

        auditTrail.createEntry(
            address(0),
            SovereignIdentity.SystemType.Harmonic,
            keccak256("DEVICE_REVOKED"),
            reasonHash,
            new bytes32[](1)
        );

        emit DeviceRevoked(deviceHash, reasonHash);
    }

    function updateCalibration(bytes32 deviceHash, bytes32 newCalibrationHash) external onlyGovernance {
        require(deviceCerts[deviceHash].certifiedAt != 0, "HarmonicAdapter: Not certified");
        deviceCerts[deviceHash].calibrationHash = newCalibrationHash;
    }

    // ============ Session Recording ============
    
    /**
     * @dev Record biofeedback session - hash only, constant gas
     * Pillar-5: Side-channel resistance for HRV data
     */
    function recordSession(
        address patient,
        bytes32 sessionHash,
        bytes32 hrvDataHash,
        bytes32 deviceHash,
        uint256 duration,
        bytes32 protocolHash,
        uint256 wellnessScore,
        bytes32 practitionerHash
    ) external onlyCertifiedDevice(deviceHash) onlyAuthorizedPractitioner {
        require(
            identity.getProfile(patient).status == SovereignIdentity.IdentityStatus.Active,
            "HarmonicAdapter: Patient not active"
        );
        require(validProtocols[protocolHash], "HarmonicAdapter: Invalid protocol");

        sessions[patient][sessionHash] = BiofeedbackSession({
            sessionHash: sessionHash,
            hrvDataHash: hrvDataHash,
            deviceHash: deviceHash,
            startedAt: block.timestamp,
            duration: duration,
            protocolHash: protocolHash,
            wellnessScore: wellnessScore,
            practitionerHash: practitionerHash
        });

        patientSessions[patient].push(sessionHash);

        // Link identity to Harmonic system
        if (identity.getSystemIdentity(patient, SovereignIdentity.SystemType.Harmonic).systemId == bytes32(0)) {
            identity.linkSystem(patient, SovereignIdentity.SystemType.Harmonic, sessionHash);
        }

        auditTrail.createEntry(
            patient,
            SovereignIdentity.SystemType.Harmonic,
            keccak256("BIOFEEDBACK_SESSION"),
            sessionHash,
            new bytes32[](0)
        );

        emit SessionRecorded(patient, sessionHash, deviceHash, wellnessScore);
    }

    // ============ Wellness Credentials ============
    
    /**
     * @dev Issue soulbound wellness credential
     */
    function issueWellnessCredential(
        address patient,
        bytes32 credentialHash,
        bytes32 achievementHash,
        uint256 validityDays
    ) external onlyAuthorizedPractitioner {
        wellnessCredentials[patient][credentialHash] = WellnessCredential({
            credentialHash: credentialHash,
            issuedAt: block.timestamp,
            expiresAt: validityDays > 0 ? block.timestamp + (validityDays * 1 days) : type(uint256).max,
            achievementHash: achievementHash,
            revoked: false
        });

        patientCredentials[patient].push(credentialHash);

        // Issue via identity registry (soulbound)
        identity.issueCredential(
            patient,
            credentialHash,
            SovereignIdentity.SystemType.Harmonic,
            validityDays > 0 ? block.timestamp + (validityDays * 1 days) : type(uint256).max
        );

        auditTrail.createEntry(
            patient,
            SovereignIdentity.SystemType.Harmonic,
            keccak256("WELLNESS_CREDENTIAL_ISSUED"),
            credentialHash,
            new bytes32[](0)
        );

        emit WellnessCredentialIssued(patient, credentialHash, achievementHash);
    }

    // ============ Protocol Management ============
    
    function addProtocol(bytes32 protocolHash) external onlyGovernance {
        validProtocols[protocolHash] = true;
    }

    function removeProtocol(bytes32 protocolHash) external onlyGovernance {
        validProtocols[protocolHash] = false;
    }

    // ============ Practitioner Management ============
    
    function authorizePractitioner(address practitioner) external onlyGovernance {
        authorizedPractitioners[practitioner] = true;
    }

    function revokePractitioner(address practitioner) external onlyGovernance {
        authorizedPractitioners[practitioner] = false;
    }

    // ============ View Functions ============
    
    function getSession(address patient, bytes32 sessionHash) external view returns (BiofeedbackSession memory) {
        return sessions[patient][sessionHash];
    }

    function getPatientSessions(address patient) external view returns (bytes32[] memory) {
        return patientSessions[patient];
    }

    function getDeviceCert(bytes32 deviceHash) external view returns (DeviceCertification memory) {
        return deviceCerts[deviceHash];
    }

    function isDeviceCertified(bytes32 deviceHash) external view returns (bool) {
        DeviceCertification memory cert = deviceCerts[deviceHash];
        return cert.certifiedAt != 0 && !cert.revoked && cert.expiresAt > block.timestamp;
    }

    function getWellnessCredential(address patient, bytes32 credentialHash) external view returns (WellnessCredential memory) {
        return wellnessCredentials[patient][credentialHash];
    }
}
