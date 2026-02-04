// SPDX-License-Identifier: MIT
// Pillar-1: Underground Knowledge - Merkleized access lists for batch privacy
// Pillar-2: Mental Models - Inversion: Ensure data can NEVER be lost rather than how to store it
// Pillar-3: Genius Channeled - Satoshi (immutable append-only), Florence Nightingale (precision data visualization/indexing)
// Pillar-4: Strategic Dominance - Complete audit trail = compliance supremacy
// Pillar-5: Side-Channel Resistance - Constant gas for log entries
// Pillar-6: Zettelkasten linking - Events as bi-directional links
// Pillar-7: Billionaire Mindset - Build for regulatory scrutiny

pragma solidity ^0.8.24;

import "./SovereignIdentity.sol";

/**
 * @title AuditTrail
 * @dev Immutable, append-only event log for all Terracare ecosystem actions
 *      - Every system action anchored with hash
 *      - Merkle tree roots for batch verification
 *      - Bi-directional linking between related events (Zettelkasten pattern)
 *      - Optimized for The Graph indexing
 */
contract AuditTrail {
    // ============ Structs ============
    
    struct AuditEntry {
        uint256 timestamp;
        address actor;
        SovereignIdentity.SystemType system;
        bytes32 actionHash;         // Hash of action details
        bytes32 dataHash;           // Hash of data affected
        bytes32 previousEntry;      // Link to previous entry (chain)
        bytes32[] relatedEntries;   // Bi-directional links (Zettelkasten)
        uint256 blockNumber;
        uint256 transactionIndex;
    }

    struct MerkleRoot {
        bytes32 root;
        uint256 timestamp;
        uint256 entryCount;
        address submitter;
    }

    struct ActionType {
        string name;
        SovereignIdentity.SystemType system;
        bool requiresConsent;
        uint256 retentionDays;
    }

    // ============ State ============
    
    SovereignIdentity public identityRegistry;
    address public governance;
    
    // Entry hash => AuditEntry
    mapping(bytes32 => AuditEntry) public entries;
    
    // Sequential entry list for each patient
    mapping(address => bytes32[]) public patientEntryChain;
    
    // System => entry hashes
    mapping(SovereignIdentity.SystemType => bytes32[]) public systemEntries;
    
    // Merkle roots for batch verification
    bytes32[] public merkleRootHistory;
    mapping(bytes32 => MerkleRoot) public merkleRoots;
    
    // Action type definitions
    mapping(bytes32 => ActionType) public actionTypes;
    bytes32[] public actionTypeList;
    
    // Global entry counter for ordering
    uint256 public totalEntryCount;
    
    // Last entry hash per patient (for chain linking)
    mapping(address => bytes32) public lastPatientEntry;
    
    // Authorized auditors
    mapping(address => bool) public authorizedAuditors;

    // ============ Events ============
    
    event AuditEntryCreated(
        bytes32 indexed entryHash,
        address indexed patient,
        address indexed actor,
        SovereignIdentity.SystemType system,
        bytes32 actionHash,
        bytes32 dataHash,
        bytes32 previousEntry,
        uint256 timestamp
    );
    
    event EntriesLinked(
        bytes32 indexed entry1,
        bytes32 indexed entry2,
        string relationType
    );
    
    event MerkleRootSubmitted(
        bytes32 indexed root,
        uint256 entryCount,
        address submitter
    );
    
    event ActionTypeRegistered(
        bytes32 indexed actionTypeHash,
        string name,
        SovereignIdentity.SystemType system
    );

    // ============ Modifiers ============
    
    modifier onlyGovernance() {
        require(msg.sender == governance, "AuditTrail: Not governance");
        _;
    }

    modifier onlyAuthorizedAuditor() {
        require(
            authorizedAuditors[msg.sender] || msg.sender == governance,
            "AuditTrail: Not authorized"
        );
        _;
    }

    modifier onlySystemAdapter() {
        require(
            identityRegistry.isSystemAdapter(msg.sender) || msg.sender == governance,
            "AuditTrail: Not system adapter"
        );
        _;
    }

    // ============ Constructor ============
    
    constructor(address _identityRegistry) {
        identityRegistry = SovereignIdentity(_identityRegistry);
        governance = msg.sender;
    }

    // ============ Action Type Management ============
    
    function registerActionType(
        bytes32 actionTypeHash,
        string calldata name,
        SovereignIdentity.SystemType system,
        bool requiresConsent,
        uint256 retentionDays
    ) external onlyGovernance {
        actionTypes[actionTypeHash] = ActionType({
            name: name,
            system: system,
            requiresConsent: requiresConsent,
            retentionDays: retentionDays
        });
        actionTypeList.push(actionTypeHash);
        
        emit ActionTypeRegistered(actionTypeHash, name, system);
    }

    // ============ Audit Entry Creation ============
    
    /**
     * @dev Create an audit entry - append-only, immutable
     * Pillar-2: Inversion - Build system where data cannot be lost
     */
    function createEntry(
        address patient,
        SovereignIdentity.SystemType system,
        bytes32 actionHash,
        bytes32 dataHash,
        bytes32[] calldata relatedEntries
    ) external onlySystemAdapter returns (bytes32 entryHash) {
        
        // Generate entry hash (deterministic)
        entryHash = keccak256(abi.encodePacked(
            patient,
            msg.sender,
            system,
            actionHash,
            dataHash,
            block.timestamp,
            totalEntryCount
        ));

        // Link to previous entry for this patient (chain pattern)
        bytes32 previousEntry = lastPatientEntry[patient];

        entries[entryHash] = AuditEntry({
            timestamp: block.timestamp,
            actor: msg.sender,
            system: system,
            actionHash: actionHash,
            dataHash: dataHash,
            previousEntry: previousEntry,
            relatedEntries: relatedEntries,
            blockNumber: block.number,
            transactionIndex: tx.origin == msg.sender ? 0 : 1 // Simplified
        });

        // Update chains
        patientEntryChain[patient].push(entryHash);
        systemEntries[system].push(entryHash);
        lastPatientEntry[patient] = entryHash;
        totalEntryCount++;

        // Emit with all indexed fields for The Graph
        emit AuditEntryCreated(
            entryHash,
            patient,
            msg.sender,
            system,
            actionHash,
            dataHash,
            previousEntry,
            block.timestamp
        );

        // Create bi-directional links (Zettelkasten pattern)
        for (uint i = 0; i < relatedEntries.length; i++) {
            emit EntriesLinked(entryHash, relatedEntries[i], "RELATED");
        }

        return entryHash;
    }

    /**
     * @dev Batch create entries for efficiency
     */
    function createBatchEntries(
        address[] calldata patients,
        SovereignIdentity.SystemType[] calldata systems,
        bytes32[] calldata actionHashes,
        bytes32[] calldata dataHashes
    ) external onlySystemAdapter returns (bytes32[] memory entryHashes) {
        require(
            patients.length == systems.length &&
            systems.length == actionHashes.length &&
            actionHashes.length == dataHashes.length,
            "AuditTrail: Array length mismatch"
        );

        entryHashes = new bytes32[](patients.length);
        
        for (uint i = 0; i < patients.length; i++) {
            entryHashes[i] = this.createEntry(
                patients[i],
                systems[i],
                actionHashes[i],
                dataHashes[i],
                new bytes32[](0)
            );
        }

        return entryHashes;
    }

    // ============ Merkle Tree Verification ============
    
    /**
     * @dev Submit Merkle root for batch verification
     * Pillar-1: Merkleized access lists for batch privacy
     */
    function submitMerkleRoot(bytes32 root, uint256 entryCount) external onlyAuthorizedAuditor {
        merkleRoots[root] = MerkleRoot({
            root: root,
            timestamp: block.timestamp,
            entryCount: entryCount,
            submitter: msg.sender
        });
        merkleRootHistory.push(root);

        emit MerkleRootSubmitted(root, entryCount, msg.sender);
    }

    /**
     * @dev Verify entry is in Merkle tree
     */
    function verifyMerkleEntry(
        bytes32 root,
        bytes32 entryHash,
        bytes32[] calldata proof
    ) external view returns (bool) {
        bytes32 computedHash = entryHash;
        
        for (uint i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            
            if (computedHash < proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash == root;
    }

    // ============ Linking (Zettelkasten Pattern) ============
    
    /**
     * @dev Add bi-directional link between entries
     * Pillar-6: Zettelkasten linking - contracts as notes, events as bi-directional links
     */
    function linkEntries(
        bytes32 entry1,
        bytes32 entry2,
        string calldata relationType
    ) external onlyAuthorizedAuditor {
        require(entries[entry1].timestamp != 0, "AuditTrail: Entry 1 not found");
        require(entries[entry2].timestamp != 0, "AuditTrail: Entry 2 not found");
        
        entries[entry1].relatedEntries.push(entry2);
        entries[entry2].relatedEntries.push(entry1);
        
        emit EntriesLinked(entry1, entry2, relationType);
    }

    // ============ Access Control ============
    
    function setAuthorizedAuditor(address auditor, bool authorized) external onlyGovernance {
        authorizedAuditors[auditor] = authorized;
    }

    // ============ View Functions ============
    
    function getEntry(bytes32 entryHash) external view returns (AuditEntry memory) {
        return entries[entryHash];
    }

    function getPatientEntries(address patient) external view returns (bytes32[] memory) {
        return patientEntryChain[patient];
    }

    function getPatientEntryCount(address patient) external view returns (uint256) {
        return patientEntryChain[patient].length;
    }

    function getSystemEntries(SovereignIdentity.SystemType system) external view returns (bytes32[] memory) {
        return systemEntries[system];
    }

    function getMerkleRootHistory() external view returns (bytes32[] memory) {
        return merkleRootHistory;
    }

    function verifyEntryChain(address patient, bytes32 entryHash) external view returns (bool valid) {
        bytes32 current = entryHash;
        
        while (current != bytes32(0)) {
            AuditEntry memory entry = entries[current];
            if (entry.timestamp == 0) return false;
            current = entry.previousEntry;
        }
        
        return true;
    }

    /**
     * @dev Get audit trail statistics
     */
    function getStatistics() external view returns (
        uint256 totalEntries,
        uint256 totalMerkleRoots,
        uint256 totalActionTypes
    ) {
        return (totalEntryCount, merkleRootHistory.length, actionTypeList.length);
    }

    // ============ Retention Management ============
    
    /**
     * @dev Check if entry is within retention period
     */
    function isWithinRetention(bytes32 entryHash, bytes32 actionTypeHash) external view returns (bool) {
        AuditEntry memory entry = entries[entryHash];
        ActionType memory action = actionTypes[actionTypeHash];
        
        if (entry.timestamp == 0 || action.retentionDays == 0) return true;
        
        uint256 retentionSeconds = action.retentionDays * 1 days;
        return (block.timestamp - entry.timestamp) <= retentionSeconds;
    }
}
