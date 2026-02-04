// SPDX-License-Identifier: MIT
// Pillar-1: Frequency protocol hashes anchored immutably
// Pillar-2: First Principles: Sound healing requires precise frequency tracking
// Pillar-3: Genius Channeled - Buckminster Fuller (resonance in systems)
// Pillar-4: Device calibration as strategic asset
// Pillar-5: Constant gas for treatment logs
// Pillar-6: Linked treatment protocols (Zettelkasten)
// Pillar-7: Generational frequency knowledge

pragma solidity ^0.8.24;

import "../SovereignIdentity.sol";
import "../AccessGovernor.sol";
import "../AuditTrail.sol";

/**
 * @title TerratoneAdapter
 * @dev Frequency therapy module adapter for Terracare
 *      - Frequency protocol hashes on-chain
 *      - Treatment session logs with device calibration
 *      - Certification for frequency practitioners
 *      - Protocol versioning and lineage tracking
 */
contract TerratoneAdapter {
    // ============ Structs ============
    
    struct FrequencyProtocol {
        bytes32 protocolHash;       // Hash of full protocol specification
        bytes32 parentProtocol;     // Parent protocol for versioning
        bytes32[] childProtocols;   // Child protocols derived from this
        uint256 createdAt;
        address creator;
        bool verified;
        bytes32 frequencySpecsHash; // Technical specifications hash
    }

    struct TreatmentSession {
        bytes32 sessionHash;
        bytes32 protocolHash;       // Protocol used
        bytes32 deviceHash;         // Device used
        uint256 startedAt;
        uint256 duration;           // Seconds
        uint256 frequency;          // Primary frequency in Hz (public)
        bytes32 settingsHash;       // Encrypted settings
        bytes32 outcomeHash;        // Outcome data hash
        address practitioner;
    }

    struct DeviceCalibration {
        bytes32 deviceHash;
        bytes32 calibrationHash;
        uint256 calibratedAt;
        uint256 validUntil;
        bytes32 technicianHash;
    }

    // ============ State ============
    
    SovereignIdentity public identity;
    AccessGovernor public accessGovernor;
    AuditTrail public auditTrail;
    
    address public governance;
    
    // Protocol hash => protocol
    mapping(bytes32 => FrequencyProtocol) public protocols;
    bytes32[] public protocolList;
    
    // Session hash => session
    mapping(bytes32 => TreatmentSession) public sessions;
    mapping(address => bytes32[]) public patientSessions;
    
    // Device hash => calibration
    mapping(bytes32 => DeviceCalibration) public calibrations;
    
    // Authorized practitioners
    mapping(address => bool) public authorizedPractitioners;
    mapping(address => bytes32) public practitionerCerts;

    // ============ Events ============
    
    event ProtocolRegistered(
        bytes32 indexed protocolHash,
        bytes32 indexed parentProtocol,
        address creator
    );
    
    event ProtocolVerified(bytes32 indexed protocolHash);
    
    event TreatmentSessionRecorded(
        address indexed patient,
        bytes32 indexed sessionHash,
        bytes32 protocolHash,
        uint256 frequency
    );
    
    event DeviceCalibrated(
        bytes32 indexed deviceHash,
        bytes32 calibrationHash,
        uint256 validUntil
    );

    // ============ Modifiers ============
    
    modifier onlyGovernance() {
        require(msg.sender == governance, "TerratoneAdapter: Not governance");
        _;
    }

    modifier onlyAuthorizedPractitioner() {
        require(
            authorizedPractitioners[msg.sender] || msg.sender == governance,
            "TerratoneAdapter: Not authorized"
        );
        _;
    }

    modifier onlyVerifiedProtocol(bytes32 protocolHash) {
        require(protocols[protocolHash].verified, "TerratoneAdapter: Protocol not verified");
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

    // ============ Protocol Management ============
    
    /**
     * @dev Register new frequency protocol
     * Pillar-6: Zettelkasten linking - protocols link to parents/children
     */
    function registerProtocol(
        bytes32 protocolHash,
        bytes32 parentProtocol,
        bytes32 frequencySpecsHash
    ) external onlyAuthorizedPractitioner {
        require(protocols[protocolHash].createdAt == 0, "TerratoneAdapter: Protocol exists");

        protocols[protocolHash] = FrequencyProtocol({
            protocolHash: protocolHash,
            parentProtocol: parentProtocol,
            childProtocols: new bytes32[](0),
            createdAt: block.timestamp,
            creator: msg.sender,
            verified: false,
            frequencySpecsHash: frequencySpecsHash
        });

        protocolList.push(protocolHash);

        // Link to parent (Zettelkasten pattern)
        if (parentProtocol != bytes32(0)) {
            protocols[parentProtocol].childProtocols.push(protocolHash);
        }

        auditTrail.createEntry(
            address(0),
            SovereignIdentity.SystemType.Terratone,
            keccak256("PROTOCOL_REGISTERED"),
            protocolHash,
            parentProtocol != bytes32(0) ? _toArray(parentProtocol) : new bytes32[](0)
        );

        emit ProtocolRegistered(protocolHash, parentProtocol, msg.sender);
    }

    /**
     * @dev Verify protocol - governance approval required
     */
    function verifyProtocol(bytes32 protocolHash) external onlyGovernance {
        require(protocols[protocolHash].createdAt != 0, "TerratoneAdapter: Protocol not found");
        protocols[protocolHash].verified = true;

        auditTrail.createEntry(
            address(0),
            SovereignIdentity.SystemType.Terratone,
            keccak256("PROTOCOL_VERIFIED"),
            protocolHash,
            new bytes32[](0)
        );

        emit ProtocolVerified(protocolHash);
    }

    // ============ Treatment Sessions ============
    
    /**
     * @dev Record frequency treatment session
     */
    function recordTreatment(
        address patient,
        bytes32 sessionHash,
        bytes32 protocolHash,
        bytes32 deviceHash,
        uint256 duration,
        uint256 frequency,
        bytes32 settingsHash,
        bytes32 outcomeHash
    ) external onlyVerifiedProtocol(protocolHash) onlyAuthorizedPractitioner {
        require(
            identity.getProfile(patient).status == SovereignIdentity.IdentityStatus.Active,
            "TerratoneAdapter: Patient not active"
        );
        require(calibrations[deviceHash].validUntil > block.timestamp, "TerratoneAdapter: Device not calibrated");

        sessions[sessionHash] = TreatmentSession({
            sessionHash: sessionHash,
            protocolHash: protocolHash,
            deviceHash: deviceHash,
            startedAt: block.timestamp,
            duration: duration,
            frequency: frequency,
            settingsHash: settingsHash,
            outcomeHash: outcomeHash,
            practitioner: msg.sender
        });

        patientSessions[patient].push(sessionHash);

        // Link identity
        if (identity.getSystemIdentity(patient, SovereignIdentity.SystemType.Terratone).systemId == bytes32(0)) {
            identity.linkSystem(patient, SovereignIdentity.SystemType.Terratone, sessionHash);
        }

        auditTrail.createEntry(
            patient,
            SovereignIdentity.SystemType.Terratone,
            keccak256("TREATMENT_SESSION"),
            sessionHash,
            new bytes32[](1)
        );

        emit TreatmentSessionRecorded(patient, sessionHash, protocolHash, frequency);
    }

    // ============ Device Calibration ============
    
    function recordCalibration(
        bytes32 deviceHash,
        bytes32 calibrationHash,
        uint256 validityDays,
        bytes32 technicianHash
    ) external onlyGovernance {
        calibrations[deviceHash] = DeviceCalibration({
            deviceHash: deviceHash,
            calibrationHash: calibrationHash,
            calibratedAt: block.timestamp,
            validUntil: block.timestamp + (validityDays * 1 days),
            technicianHash: technicianHash
        });

        auditTrail.createEntry(
            address(0),
            SovereignIdentity.SystemType.Terratone,
            keccak256("DEVICE_CALIBRATED"),
            deviceHash,
            new bytes32[](0)
        );

        emit DeviceCalibrated(deviceHash, calibrationHash, block.timestamp + (validityDays * 1 days));
    }

    // ============ Practitioner Management ============
    
    function authorizePractitioner(address practitioner, bytes32 certHash) external onlyGovernance {
        authorizedPractitioners[practitioner] = true;
        practitionerCerts[practitioner] = certHash;
        
        identity.issueCredential(
            practitioner,
            certHash,
            SovereignIdentity.SystemType.Terratone,
            block.timestamp + 365 days
        );
    }

    function revokePractitioner(address practitioner) external onlyGovernance {
        authorizedPractitioners[practitioner] = false;
    }

    // ============ View Functions ============
    
    function getProtocol(bytes32 protocolHash) external view returns (FrequencyProtocol memory) {
        return protocols[protocolHash];
    }

    function getSession(bytes32 sessionHash) external view returns (TreatmentSession memory) {
        return sessions[sessionHash];
    }

    function getPatientSessions(address patient) external view returns (bytes32[] memory) {
        return patientSessions[patient];
    }

    function getCalibration(bytes32 deviceHash) external view returns (DeviceCalibration memory) {
        return calibrations[deviceHash];
    }

    function isDeviceCalibrated(bytes32 deviceHash) external view returns (bool) {
        return calibrations[deviceHash].validUntil > block.timestamp;
    }

    function _toArray(bytes32 value) internal pure returns (bytes32[] memory) {
        bytes32[] memory arr = new bytes32[](1);
        arr[0] = value;
        return arr;
    }
}
