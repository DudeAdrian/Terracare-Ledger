// SPDX-License-Identifier: MIT
/**
 * @title AccessGovernor
 * @notice Merkle-based cross-system permission orchestrator
 * 
 * INSPIRED BY:
 * - Pillar 1 (Underground Knowledge): Merkleized access, commit-reveal schemes
 * - Pillar 2 (Mental Models): First Principles - permissions as mathematical truth
 * - Pillar 5 (Black Market Tactics): Constant gas costs via Merkle proofs
 * 
 * ARCHITECTURE:
 * - Merkle trees for gas-efficient permission verification
 * - Role-based access with hierarchical inheritance
 * - Time-bound permissions with automatic expiration
 * - Cross-system permission synchronization
 */
pragma solidity ^0.8.24;

import {LibDiamond} from "../libraries/LibDiamond.sol";

/**
 * @notice AccessGovernor Diamond Storage
 */
library AccessGovernorStorage {
    bytes32 constant STORAGE_POSITION = keccak256("terracare.accessgovernor.storage");
    
    // Role hierarchy
    enum Role {
        None,           // 0 - No permissions
        Patient,        // 1 - Data owner
        Caregiver,      // 2 - General care provider
        Specialist,     // 3 - Medical specialist
        Emergency,      // 4 - Emergency override access
        Admin,          // 5 - System administrator
        System          // 6 - Automated system (AI, devices)
    }
    
    // Permission types (bitmask for efficiency)
    uint256 constant PERMISSION_READ = 1 << 0;
    uint256 constant PERMISSION_WRITE = 1 << 1;
    uint256 constant PERMISSION_DELETE = 1 << 2;
    uint256 constant PERMISSION_ADMIN = 1 << 3;
    uint256 constant PERMISSION_EMERGENCY = 1 << 4;
    
    struct Permission {
        uint256 permissionMask;     // Bitmask of permissions
        uint256 grantedAt;
        uint256 expiresAt;          // 0 = no expiration
        bytes32 scopeHash;          // Hash of data scope (records, systems, etc.)
        bytes32 merkleRoot;         // Root of allowed actions tree
        bool isActive;
    }
    
    struct Storage {
        // Patient -> Grantee -> Permission
        mapping(address => mapping(address => Permission)) permissions;
        
        // Role assignments (can have multiple roles via bitmask)
        mapping(address => uint256) roleAssignments;
        
        // Merkle roots for batch permission updates
        mapping(address => bytes32) patientMerkleRoots;
        
        // Emergency multisig state
        mapping(bytes32 => EmergencyAction) emergencyActions;
        mapping(address => bool) medicalCouncil;
        uint256 councilCount;
        
        // Break-glass mode (system-wide emergency)
        bool breakGlassMode;
        address breakGlassInitiator;
        uint256 breakGlassExpiry;
        
        // ERC-2771 forwarders
        mapping(address => bool) trustedForwarders;
    }
    
    struct EmergencyAction {
        address target;
        bytes32 actionHash;
        uint256 signatures;
        mapping(address => bool) hasSigned;
        bool executed;
        uint256 createdAt;
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
interface IAccessGovernorEvents {
    event PermissionGranted(
        address indexed patient,
        address indexed grantee,
        uint256 permissionMask,
        uint256 expiresAt,
        bytes32 scopeHash
    );
    
    event PermissionRevoked(
        address indexed patient,
        address indexed grantee,
        uint256 timestamp
    );
    
    event RoleAssigned(
        address indexed account,
        AccessGovernorStorage.Role indexed role,
        uint256 timestamp
    );
    
    event MerkleRootUpdated(
        address indexed patient,
        bytes32 indexed newRoot,
        uint256 timestamp
    );
    
    event EmergencyActionProposed(
        bytes32 indexed actionId,
        address indexed target,
        bytes32 actionHash,
        uint256 timestamp
    );
    
    event EmergencyActionSigned(
        bytes32 indexed actionId,
        address indexed councilMember,
        uint256 signatureCount
    );
    
    event EmergencyActionExecuted(
        bytes32 indexed actionId,
        uint256 timestamp
    );
    
    event BreakGlassActivated(
        address indexed initiator,
        uint256 expiresAt,
        uint256 timestamp
    );
    
    event BreakGlassDeactivated(
        address indexed initiator,
        uint256 timestamp
    );
}

/**
 * @title AccessGovernor Facet
 * @notice Diamond facet for cross-system permission management
 */
contract AccessGovernor is IAccessGovernorEvents {
    
    uint256 constant EMERGENCY_MULTISIG_THRESHOLD = 3;
    uint256 constant EMERGENCY_ACTION_TIMEOUT = 7 days;
    uint256 constant BREAK_GLASS_DURATION = 24 hours;
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }
    
    modifier onlyMedicalCouncil() {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        require(s.medicalCouncil[_msgSender()], "AccessGovernor: Not council member");
        _;
    }
    
    modifier validPermission(address _patient, address _grantee) {
        require(_patient != address(0), "AccessGovernor: Invalid patient");
        require(_grantee != address(0), "AccessGovernor: Invalid grantee");
        _;
    }
    
    // ============ ERC-2771 Support ============
    
    function _msgSender() internal view returns (address) {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
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
    
    // ============ Permission Management ============
    
    /**
     * @notice Grant permissions to a caregiver/provider
     * @param _grantee Address receiving permission
     * @param _permissionMask Bitmask of permissions
     * @param _expiresAt Timestamp when permission expires (0 = never)
     * @param _scopeHash Hash of data scope
     * @param _merkleRoot Root of allowed actions Merkle tree
     */
    function grantPermission(
        address _grantee,
        uint256 _permissionMask,
        uint256 _expiresAt,
        bytes32 _scopeHash,
        bytes32 _merkleRoot
    ) external {
        address patient = _msgSender();
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        
        s.permissions[patient][_grantee] = AccessGovernorStorage.Permission({
            permissionMask: _permissionMask,
            grantedAt: block.timestamp,
            expiresAt: _expiresAt,
            scopeHash: _scopeHash,
            merkleRoot: _merkleRoot,
            isActive: true
        });
        
        emit PermissionGranted(patient, _grantee, _permissionMask, _expiresAt, _scopeHash);
    }
    
    /**
     * @notice Revoke all permissions from a grantee
     * @param _grantee Address losing permission
     */
    function revokePermission(address _grantee) external {
        address patient = _msgSender();
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        
        delete s.permissions[patient][_grantee];
        
        emit PermissionRevoked(patient, _grantee, block.timestamp);
    }
    
    /**
     * @notice Verify permission with Merkle proof (gas-efficient)
     * @param _patient Data owner
     * @param _grantee Requesting address
     * @param _actionHash Hash of specific action
     * @param _merkleProof Proof that action is allowed
     * @return hasPermission True if permission verified
     */
    function verifyPermissionWithProof(
        address _patient,
        address _grantee,
        bytes32 _actionHash,
        bytes32[] calldata _merkleProof
    ) external view returns (bool hasPermission) {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        AccessGovernorStorage.Permission storage perm = s.permissions[_patient][_grantee];
        
        if (!perm.isActive) return false;
        if (perm.expiresAt != 0 && block.timestamp > perm.expiresAt) return false;
        
        // Verify Merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(_actionHash));
        bytes32 computedHash = leaf;
        
        for (uint256 i = 0; i < _merkleProof.length; i++) {
            bytes32 proofElement = _merkleProof[i];
            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        
        return computedHash == perm.merkleRoot;
    }
    
    /**
     * @notice Check basic permission (no Merkle proof required)
     * @param _patient Data owner
     * @param _grantee Requesting address
     * @param _permission Bit to check
     * @return hasPermission True if granted
     */
    function checkPermission(
        address _patient,
        address _grantee,
        uint256 _permission
    ) external view returns (bool hasPermission) {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        AccessGovernorStorage.Permission storage perm = s.permissions[_patient][_grantee];
        
        if (s.breakGlassMode && block.timestamp < s.breakGlassExpiry) {
            return true;  // Emergency override
        }
        
        if (!perm.isActive) return false;
        if (perm.expiresAt != 0 && block.timestamp > perm.expiresAt) return false;
        
        return (perm.permissionMask & _permission) != 0;
    }
    
    // ============ Role Management ============
    
    /**
     * @notice Assign role to account (admin only)
     */
    function assignRole(address _account, AccessGovernorStorage.Role _role) external onlyOwner {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        s.roleAssignments[_account] |= (1 << uint256(_role));
        
        emit RoleAssigned(_account, _role, block.timestamp);
    }
    
    /**
     * @notice Check if account has role
     */
    function hasRole(address _account, AccessGovernorStorage.Role _role) external view returns (bool) {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        return (s.roleAssignments[_account] & (1 << uint256(_role))) != 0;
    }
    
    // ============ Emergency Multisig (3-of-5 Medical Council) ============
    
    /**
     * @notice Add medical council member
     */
    function addMedicalCouncilMember(address _member) external onlyOwner {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        require(!s.medicalCouncil[_member], "AccessGovernor: Already council member");
        
        s.medicalCouncil[_member] = true;
        s.councilCount++;
    }
    
    /**
     * @notice Propose emergency action
     * @param _actionId Unique action identifier
     * @param _target Target address
     * @param _actionHash Hash of proposed action
     */
    function proposeEmergencyAction(
        bytes32 _actionId,
        address _target,
        bytes32 _actionHash
    ) external onlyMedicalCouncil {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        
        require(s.councilCount >= 5, "AccessGovernor: Insufficient council");
        
        AccessGovernorStorage.EmergencyAction storage action = s.emergencyActions[_actionId];
        action.target = _target;
        action.actionHash = _actionHash;
        action.createdAt = block.timestamp;
        
        emit EmergencyActionProposed(_actionId, _target, _actionHash, block.timestamp);
    }
    
    /**
     * @notice Sign emergency action
     */
    function signEmergencyAction(bytes32 _actionId) external onlyMedicalCouncil {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        AccessGovernorStorage.EmergencyAction storage action = s.emergencyActions[_actionId];
        
        require(action.target != address(0), "AccessGovernor: Action not found");
        require(!action.executed, "AccessGovernor: Already executed");
        require(!action.hasSigned[_msgSender()], "AccessGovernor: Already signed");
        require(block.timestamp <= action.createdAt + EMERGENCY_ACTION_TIMEOUT, "AccessGovernor: Expired");
        
        action.hasSigned[_msgSender()] = true;
        action.signatures++;
        
        emit EmergencyActionSigned(_actionId, _msgSender(), action.signatures);
        
        // Auto-execute at threshold
        if (action.signatures >= EMERGENCY_MULTISIG_THRESHOLD) {
            action.executed = true;
            emit EmergencyActionExecuted(_actionId, block.timestamp);
        }
    }
    
    /**
     * @notice Check if emergency action is approved
     */
    function isEmergencyActionApproved(bytes32 _actionId) external view returns (bool) {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        return s.emergencyActions[_actionId].executed;
    }
    
    // ============ Break-Glass Emergency Mode ============
    
    /**
     * @notice Activate break-glass mode (system-wide emergency)
     * @dev Requires medical council role
     */
    function activateBreakGlass() external onlyMedicalCouncil {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        
        s.breakGlassMode = true;
        s.breakGlassInitiator = _msgSender();
        s.breakGlassExpiry = block.timestamp + BREAK_GLASS_DURATION;
        
        emit BreakGlassActivated(_msgSender(), s.breakGlassExpiry, block.timestamp);
    }
    
    /**
     * @notice Deactivate break-glass mode
     */
    function deactivateBreakGlass() external {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        
        require(
            s.breakGlassInitiator == _msgSender() || 
            LibDiamond.isContractOwner(_msgSender()),
            "AccessGovernor: Not authorized"
        );
        
        s.breakGlassMode = false;
        s.breakGlassInitiator = address(0);
        s.breakGlassExpiry = 0;
        
        emit BreakGlassDeactivated(_msgSender(), block.timestamp);
    }
    
    function isBreakGlassActive() external view returns (bool) {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        return s.breakGlassMode && block.timestamp < s.breakGlassExpiry;
    }
    
    // ============ Batch Merkle Updates ============
    
    /**
     * @notice Update patient's Merkle root for batch permission changes
     * @param _newRoot New Merkle root
     */
    function updateMerkleRoot(bytes32 _newRoot) external {
        address patient = _msgSender();
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        
        s.patientMerkleRoots[patient] = _newRoot;
        
        emit MerkleRootUpdated(patient, _newRoot, block.timestamp);
    }
    
    /**
     * @notice Verify action against patient's Merkle root
     */
    function verifyAgainstPatientMerkle(
        address _patient,
        bytes32 _actionHash,
        bytes32[] calldata _merkleProof
    ) external view returns (bool) {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        bytes32 root = s.patientMerkleRoots[_patient];
        
        if (root == bytes32(0)) return false;
        
        bytes32 leaf = keccak256(abi.encodePacked(_actionHash));
        bytes32 computedHash = leaf;
        
        for (uint256 i = 0; i < _merkleProof.length; i++) {
            bytes32 proofElement = _merkleProof[i];
            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        
        return computedHash == root;
    }
    
    // ============ Admin Functions ============
    
    function setTrustedForwarder(address _forwarder, bool _trusted) external onlyOwner {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        s.trustedForwarders[_forwarder] = _trusted;
    }
    
    // ============ View Functions ============
    
    function getPermissionDetails(
        address _patient,
        address _grantee
    ) external view returns (AccessGovernorStorage.Permission memory) {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        return s.permissions[_patient][_grantee];
    }
    
    function getPatientMerkleRoot(address _patient) external view returns (bytes32) {
        AccessGovernorStorage.Storage storage s = AccessGovernorStorage.getStorage();
        return s.patientMerkleRoots[_patient];
    }
}
