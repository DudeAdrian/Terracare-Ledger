// SPDX-License-Identifier: MIT
// Pillar-1: Underground Knowledge - Soulbound patterns (ERC-5192), Stealth addresses (EIP-5564)
// Pillar-2: Mental Models - First Principles: Patient owns identity, not institution
// Pillar-3: Genius Channeled - Vitalik (account abstraction), Satoshi (immutable identity)
// Pillar-4: Strategic Dominance - Own the identity layer, own the ecosystem
// Pillar-5: Black Market Tactics - Dead Man's Switch for estate planning
// Pillar-6: Barbell Strategy - 90% OZ patterns, 10% aggressive sovereignty features
// Pillar-7: Billionaire Mindset - Build for centuries, not quarters

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title SovereignIdentity
 * @dev Master registry linking all 9 Terracare system IDs to one sovereign patient identity
 *      - Wallet address is the root identity
 *      - Maps to TholosID, HarmonicDeviceID, TerratoneCert, SofieOSID, LlamaSessionID, MapGeofenceID
 *      - Implements soulbound pattern (non-transferable identity)
 *      - Includes Dead Man's Switch for estate planning
 *      - Hash-only: No PHI stored, only encrypted pointers and hashes
 */
contract SovereignIdentity {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ============ Enums ============
    enum SystemType {
        Unknown,
        Heartware,      // UI Layer
        Tholos,         // Clinical records
        Harmonic,       // Biofeedback/wellness
        Terratone,      // Frequency therapy
        SofieOS,        // Core OS
        LlamaBackend,   // AI inference
        MapSystem,      // Geographic layer
        SandIronNode,   // PoA validator
        Emergency       // Break-glass access
    }

    enum IdentityStatus {
        Unregistered,
        Active,
        Suspended,
        Deceased,       // Estate mode triggered
        Revoked
    }

    // ============ Structs ============
    struct SystemIdentity {
        bytes32 systemId;           // Hash of external system ID
        uint256 registeredAt;
        uint256 lastVerified;
        bool active;
    }

    struct SovereignProfile {
        IdentityStatus status;
        uint256 createdAt;
        uint256 lastActivity;
        bytes32 encryptedDataPointer;  // IPFS CID or S3 encrypted pointer hash
        uint256 deadMansSwitchDays;    // Days of inactivity before estate mode
        address estateBeneficiary;     // Who gets access when deceased
        bool estateModeTriggered;
    }

    struct Credential {
        bytes32 credentialHash;     // Hash of medical credential (soulbound)
        SystemType issuer;
        uint256 issuedAt;
        uint256 expiresAt;
        bool revoked;
    }

    // ============ State ============
    address public governance;
    address public pendingGovernance;
    
    // patient wallet => profile
    mapping(address => SovereignProfile) public profiles;
    
    // patient => system type => system identity
    mapping(address => mapping(SystemType => SystemIdentity)) public systemIdentities;
    
    // patient => credential hash => credential (soulbound tokens as credentials)
    mapping(address => mapping(bytes32 => Credential)) public credentials;
    mapping(address => bytes32[]) public patientCredentialList;
    
    // Nonce tracking for meta-transactions (ERC-2771 pattern)
    mapping(address => uint256) public nonces;
    
    // Authorized relayers for gasless transactions
    mapping(address => bool) public authorizedRelayers;
    
    // System adapters authorized to write identity data
    mapping(SystemType => address) public systemAdapters;
    mapping(address => bool) public isSystemAdapter;

    // ============ Events ============
    event IdentityCreated(address indexed patient, uint256 createdAt, bytes32 encryptedPointer);
    event SystemLinked(address indexed patient, SystemType indexed system, bytes32 systemId);
    event SystemUnlinked(address indexed patient, SystemType indexed system);
    event CredentialIssued(address indexed patient, bytes32 indexed credentialHash, SystemType issuer);
    event CredentialRevoked(address indexed patient, bytes32 indexed credentialHash);
    event EstateModeTriggered(address indexed patient, address indexed beneficiary);
    event ActivityRecorded(address indexed patient, uint256 timestamp);
    event RelayerAuthorized(address indexed relayer, bool authorized);
    event GovernanceTransfer(address indexed previousGov, address indexed newGov);
    event DeadMansSwitchConfigured(address indexed patient, uint256 daysOfInactivity, address beneficiary);

    // ============ Modifiers ============
    modifier onlyGovernance() {
        require(msg.sender == governance, "SovereignIdentity: Not governance");
        _;
    }

    modifier onlySystemAdapter(SystemType system) {
        require(
            msg.sender == systemAdapters[system] || msg.sender == governance,
            "SovereignIdentity: Unauthorized system"
        );
        _;
    }

    modifier onlyActiveIdentity(address patient) {
        require(profiles[patient].status == IdentityStatus.Active, "SovereignIdentity: Not active");
        _;
    }

    modifier onlyPatientOrRelayer(address patient) {
        require(
            msg.sender == patient || authorizedRelayers[msg.sender],
            "SovereignIdentity: Not patient or relayer"
        );
        _;
    }

    // ============ Constructor ============
    constructor() {
        governance = msg.sender;
    }

    // ============ Governance ============
    function transferGovernance(address newGovernance) external onlyGovernance {
        require(newGovernance != address(0), "SovereignIdentity: Zero address");
        pendingGovernance = newGovernance;
    }

    function acceptGovernance() external {
        require(msg.sender == pendingGovernance, "SovereignIdentity: Not pending");
        emit GovernanceTransfer(governance, pendingGovernance);
        governance = pendingGovernance;
        pendingGovernance = address(0);
    }

    function setSystemAdapter(SystemType system, address adapter) external onlyGovernance {
        // Remove old adapter from authorized list
        if (systemAdapters[system] != address(0)) {
            isSystemAdapter[systemAdapters[system]] = false;
        }
        systemAdapters[system] = adapter;
        isSystemAdapter[adapter] = true;
    }

    function setRelayerAuthorization(address relayer, bool authorized) external onlyGovernance {
        authorizedRelayers[relayer] = authorized;
        emit RelayerAuthorized(relayer, authorized);
    }

    // ============ Identity Management ============
    
    /**
     * @dev Create sovereign identity - the root of all Terracare systems
     * @param encryptedDataPointer Hash of encrypted PHI storage location
     */
    function createIdentity(bytes32 encryptedDataPointer) external {
        require(
            profiles[msg.sender].status == IdentityStatus.Unregistered,
            "SovereignIdentity: Already exists"
        );
        
        profiles[msg.sender] = SovereignProfile({
            status: IdentityStatus.Active,
            createdAt: block.timestamp,
            lastActivity: block.timestamp,
            encryptedDataPointer: encryptedDataPointer,
            deadMansSwitchDays: 90,  // Default 90 days
            estateBeneficiary: address(0),
            estateModeTriggered: false
        });

        emit IdentityCreated(msg.sender, block.timestamp, encryptedDataPointer);
    }

    /**
     * @dev Link an external system ID to sovereign identity
     * Can only be called by system adapters or governance
     */
    function linkSystem(
        address patient,
        SystemType system,
        bytes32 systemId
    ) external onlySystemAdapter(system) onlyActiveIdentity(patient) {
        systemIdentities[patient][system] = SystemIdentity({
            systemId: systemId,
            registeredAt: block.timestamp,
            lastVerified: block.timestamp,
            active: true
        });

        emit SystemLinked(patient, system, systemId);
    }

    function unlinkSystem(
        address patient,
        SystemType system
    ) external onlySystemAdapter(system) {
        delete systemIdentities[patient][system];
        emit SystemUnlinked(patient, system);
    }

    function verifySystem(address patient, SystemType system) external onlySystemAdapter(system) {
        systemIdentities[patient][system].lastVerified = block.timestamp;
    }

    // ============ Credential Management (Soulbound Pattern) ============
    
    /**
     * @dev Issue a soulbound credential - non-transferable medical credential
     * Pillar-1: ERC-5192 style soulbound tokens for medical credentials
     */
    function issueCredential(
        address patient,
        bytes32 credentialHash,
        SystemType issuer,
        uint256 expiresAt
    ) external onlySystemAdapter(issuer) onlyActiveIdentity(patient) {
        require(credentials[patient][credentialHash].issuedAt == 0, "SovereignIdentity: Credential exists");

        credentials[patient][credentialHash] = Credential({
            credentialHash: credentialHash,
            issuer: issuer,
            issuedAt: block.timestamp,
            expiresAt: expiresAt,
            revoked: false
        });

        patientCredentialList[patient].push(credentialHash);
        emit CredentialIssued(patient, credentialHash, issuer);
    }

    function revokeCredential(
        address patient,
        bytes32 credentialHash
    ) external {
        Credential storage cred = credentials[patient][credentialHash];
        require(cred.issuedAt != 0, "SovereignIdentity: Credential not found");
        require(
            msg.sender == systemAdapters[cred.issuer] || msg.sender == governance,
            "SovereignIdentity: Not issuer"
        );

        cred.revoked = true;
        emit CredentialRevoked(patient, credentialHash);
    }

    function hasValidCredential(address patient, bytes32 credentialHash) external view returns (bool) {
        Credential memory cred = credentials[patient][credentialHash];
        if (cred.issuedAt == 0 || cred.revoked) return false;
        if (cred.expiresAt != 0 && cred.expiresAt < block.timestamp) return false;
        return true;
    }

    // ============ Dead Man's Switch (Estate Planning) ============
    
    /**
     * @dev Configure dead man's switch for estate planning
     * Pillar-5: Black market tactics for extreme scenarios
     */
    function configureDeadMansSwitch(
        uint256 daysOfInactivity,
        address beneficiary
    ) external onlyActiveIdentity(msg.sender) {
        require(daysOfInactivity >= 30, "SovereignIdentity: Minimum 30 days");
        require(beneficiary != address(0), "SovereignIdentity: Invalid beneficiary");

        profiles[msg.sender].deadMansSwitchDays = daysOfInactivity;
        profiles[msg.sender].estateBeneficiary = beneficiary;

        emit DeadMansSwitchConfigured(msg.sender, daysOfInactivity, beneficiary);
    }

    /**
     * @dev Record activity to reset dead man's switch timer
     */
    function recordActivity() external onlyActiveIdentity(msg.sender) {
        profiles[msg.sender].lastActivity = block.timestamp;
        emit ActivityRecorded(msg.sender, block.timestamp);
    }

    /**
     * @dev Check if dead man's switch should trigger estate mode
     */
    function checkEstateMode(address patient) external view returns (bool shouldTrigger) {
        SovereignProfile memory profile = profiles[patient];
        if (profile.status != IdentityStatus.Active) return false;
        if (profile.estateBeneficiary == address(0)) return false;
        
        uint256 inactiveTime = block.timestamp - profile.lastActivity;
        return inactiveTime > profile.deadMansSwitchDays * 1 days;
    }

    /**
     * @dev Trigger estate mode - anyone can call after inactivity period
     */
    function triggerEstateMode(address patient) external {
        require(this.checkEstateMode(patient), "SovereignIdentity: Not triggered");
        
        SovereignProfile storage profile = profiles[patient];
        profile.status = IdentityStatus.Deceased;
        profile.estateModeTriggered = true;

        emit EstateModeTriggered(patient, profile.estateBeneficiary);
    }

    // ============ Meta-Transaction Support (ERC-2771) ============
    
    /**
     * @dev Execute meta-transaction - enables gasless operations for patients
     * Pillar-1: Gasless meta-transactions for health sovereignty
     */
    function executeMetaTransaction(
        address user,
        bytes calldata functionSignature,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) external returns (bytes memory) {
        require(authorizedRelayers[msg.sender], "SovereignIdentity: Unauthorized relayer");

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(user, functionSignature, nonces[user]))
        ));

        require(
            user == digest.recover(sigV, sigR, sigS),
            "SovereignIdentity: Invalid signature"
        );

        nonces[user]++;

        // Execute the function call
        (bool success, bytes memory returnData) = address(this).call(
            abi.encodePacked(functionSignature, user)
        );
        require(success, "SovereignIdentity: Meta-tx failed");

        return returnData;
    }

    // ============ View Functions ============
    
    function getProfile(address patient) external view returns (SovereignProfile memory) {
        return profiles[patient];
    }

    function getSystemIdentity(address patient, SystemType system) external view returns (SystemIdentity memory) {
        return systemIdentities[patient][system];
    }

    function getAllCredentials(address patient) external view returns (bytes32[] memory) {
        return patientCredentialList[patient];
    }

    function isSystemActive(address patient, SystemType system) external view returns (bool) {
        return systemIdentities[patient][system].active;
    }

    function getNonce(address user) external view returns (uint256) {
        return nonces[user];
    }

    // ============ Emergency Functions ============
    
    /**
     * @dev Emergency suspend identity - governance only for safety
     */
    function emergencySuspend(address patient) external onlyGovernance {
        profiles[patient].status = IdentityStatus.Suspended;
    }

    /**
     * @dev Reactivate suspended identity
     */
    function reactivate(address patient) external onlyGovernance {
        require(profiles[patient].status == IdentityStatus.Suspended, "SovereignIdentity: Not suspended");
        profiles[patient].status = IdentityStatus.Active;
        profiles[patient].lastActivity = block.timestamp;
    }
}
