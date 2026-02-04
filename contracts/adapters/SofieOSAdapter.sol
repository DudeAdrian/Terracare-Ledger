// SPDX-License-Identifier: MIT
// Pillar-1: Hardware abstraction with on-chain device registry
// Pillar-2: First Principles: OS owns the hardware layer
// Pillar-3: Genius Channeled - Buckminster Fuller (synergetic systems)
// Pillar-4: Device management as strategic moat
// Pillar-5: Dead Man's Switch integration for devices
// Pillar-6: OODA loops for device security
// Pillar-7: Build for hardware longevity

pragma solidity ^0.8.24;

import "../SovereignIdentity.sol";
import "../AccessGovernor.sol";
import "../AuditTrail.sol";

/**
 * @title SofieOSAdapter
 * @dev Core OS integration adapter for Terracare
 *      - Device registration and management
 *      - OS-level permission caching
 *      - Hardware abstraction layer calls
 *      - Device heartbeat monitoring
 */
contract SofieOSAdapter {
    // ============ Structs ============
    
    struct Device {
        bytes32 deviceHash;
        address owner;
        bytes32 deviceType;         // "sensor", "wearable", "terminal", etc.
        bytes32 publicKeyHash;      // For encrypted communication
        uint256 registeredAt;
        uint256 lastHeartbeat;
        bool active;
        bytes32 firmwareHash;
        bytes32 configHash;         // Device configuration hash
    }

    struct PermissionCache {
        bytes32 permissionHash;
        uint256 cachedAt;
        uint256 expiresAt;
        bool valid;
    }

    struct OSCommand {
        bytes32 commandHash;
        address issuer;
        bytes32 targetDevice;
        uint256 issuedAt;
        uint256 executeAfter;
        bool executed;
        bytes32 resultHash;
    }

    // ============ State ============
    
    SovereignIdentity public identity;
    AccessGovernor public accessGovernor;
    AuditTrail public auditTrail;
    
    address public governance;
    
    // Device hash => Device
    mapping(bytes32 => Device) public devices;
    mapping(address => bytes32[]) public ownerDevices;
    
    // patient => permission cache
    mapping(address => PermissionCache) public permissionCaches;
    
    // Command hash => OSCommand
    mapping(bytes32 => OSCommand) public commands;
    
    // Authorized OS nodes
    mapping(address => bool) public authorizedOSNodes;
    
    // Heartbeat timeout (default 5 minutes)
    uint256 public heartbeatTimeout = 300;

    // ============ Events ============
    
    event DeviceRegistered(
        bytes32 indexed deviceHash,
        address indexed owner,
        bytes32 deviceType
    );
    
    event DeviceHeartbeat(
        bytes32 indexed deviceHash,
        uint256 timestamp
    );
    
    event DeviceDeactivated(
        bytes32 indexed deviceHash,
        bytes32 reasonHash
    );
    
    event PermissionCached(
        address indexed patient,
        bytes32 permissionHash,
        uint256 expiresAt
    );
    
    event OSCommandIssued(
        bytes32 indexed commandHash,
        bytes32 indexed targetDevice,
        uint256 executeAfter
    );
    
    event OSCommandExecuted(
        bytes32 indexed commandHash,
        bytes32 resultHash
    );

    // ============ Modifiers ============
    
    modifier onlyGovernance() {
        require(msg.sender == governance, "SofieOSAdapter: Not governance");
        _;
    }

    modifier onlyAuthorizedOSNode() {
        require(
            authorizedOSNodes[msg.sender] || msg.sender == governance,
            "SofieOSAdapter: Not authorized OS node"
        );
        _;
    }

    modifier onlyDeviceOwner(bytes32 deviceHash) {
        require(devices[deviceHash].owner == msg.sender, "SofieOSAdapter: Not device owner");
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

    // ============ Device Management ============
    
    /**
     * @dev Register a new device with SofieOS
     */
    function registerDevice(
        bytes32 deviceHash,
        bytes32 deviceType,
        bytes32 publicKeyHash,
        bytes32 firmwareHash
    ) external {
        require(devices[deviceHash].registeredAt == 0, "SofieOSAdapter: Device exists");
        require(
            identity.getProfile(msg.sender).status == SovereignIdentity.IdentityStatus.Active,
            "SofieOSAdapter: Owner not active"
        );

        devices[deviceHash] = Device({
            deviceHash: deviceHash,
            owner: msg.sender,
            deviceType: deviceType,
            publicKeyHash: publicKeyHash,
            registeredAt: block.timestamp,
            lastHeartbeat: block.timestamp,
            active: true,
            firmwareHash: firmwareHash,
            configHash: bytes32(0)
        });

        ownerDevices[msg.sender].push(deviceHash);

        // Link identity to SofieOS
        if (identity.getSystemIdentity(msg.sender, SovereignIdentity.SystemType.SofieOS).systemId == bytes32(0)) {
            identity.linkSystem(msg.sender, SovereignIdentity.SystemType.SofieOS, deviceHash);
        }

        auditTrail.createEntry(
            msg.sender,
            SovereignIdentity.SystemType.SofieOS,
            keccak256("DEVICE_REGISTERED"),
            deviceHash,
            new bytes32[](0)
        );

        emit DeviceRegistered(deviceHash, msg.sender, deviceType);
    }

    /**
     * @dev Device heartbeat - proves device is active
     */
    function heartbeat(bytes32 deviceHash, bytes32 statusHash) external onlyAuthorizedOSNode {
        require(devices[deviceHash].active, "SofieOSAdapter: Device inactive");
        devices[deviceHash].lastHeartbeat = block.timestamp;

        emit DeviceHeartbeat(deviceHash, block.timestamp);
    }

    /**
     * @dev Deactivate device
     */
    function deactivateDevice(bytes32 deviceHash, bytes32 reasonHash) external {
        require(
            devices[deviceHash].owner == msg.sender || msg.sender == governance,
            "SofieOSAdapter: Not authorized"
        );
        
        devices[deviceHash].active = false;

        auditTrail.createEntry(
            devices[deviceHash].owner,
            SovereignIdentity.SystemType.SofieOS,
            keccak256("DEVICE_DEACTIVATED"),
            reasonHash,
            new bytes32[](1)
        );

        emit DeviceDeactivated(deviceHash, reasonHash);
    }

    /**
     * @dev Update device configuration
     */
    function updateConfig(bytes32 deviceHash, bytes32 configHash) external onlyDeviceOwner(deviceHash) {
        devices[deviceHash].configHash = configHash;
    }

    /**
     * @dev Update firmware hash after OTA update
     */
    function updateFirmware(bytes32 deviceHash, bytes32 firmwareHash) external onlyDeviceOwner(deviceHash) {
        devices[deviceHash].firmwareHash = firmwareHash;
    }

    // ============ Permission Caching ============
    
    /**
     * @dev Cache access permissions for offline/device use
     */
    function cachePermissions(
        address patient,
        bytes32 permissionHash,
        uint256 validitySeconds
    ) external onlyAuthorizedOSNode {
        permissionCaches[patient] = PermissionCache({
            permissionHash: permissionHash,
            cachedAt: block.timestamp,
            expiresAt: block.timestamp + validitySeconds,
            valid: true
        });

        emit PermissionCached(patient, permissionHash, block.timestamp + validitySeconds);
    }

    /**
     * @dev Invalidate cached permissions
     */
    function invalidateCache(address patient) external {
        require(
            msg.sender == patient || authorizedOSNodes[msg.sender] || msg.sender == governance,
            "SofieOSAdapter: Not authorized"
        );
        permissionCaches[patient].valid = false;
    }

    // ============ OS Commands ============
    
    /**
     * @dev Issue command to device via OS
     */
    function issueCommand(
        bytes32 commandHash,
        bytes32 targetDevice,
        uint256 executeAfter
    ) external {
        require(
            devices[targetDevice].owner == msg.sender || authorizedOSNodes[msg.sender],
            "SofieOSAdapter: Not authorized"
        );

        commands[commandHash] = OSCommand({
            commandHash: commandHash,
            issuer: msg.sender,
            targetDevice: targetDevice,
            issuedAt: block.timestamp,
            executeAfter: executeAfter,
            executed: false,
            resultHash: bytes32(0)
        });

        auditTrail.createEntry(
            devices[targetDevice].owner,
            SovereignIdentity.SystemType.SofieOS,
            keccak256("OS_COMMAND_ISSUED"),
            commandHash,
            new bytes32[](0)
        );

        emit OSCommandIssued(commandHash, targetDevice, executeAfter);
    }

    /**
     * @dev Execute pending command
     */
    function executeCommand(bytes32 commandHash, bytes32 resultHash) external onlyAuthorizedOSNode {
        OSCommand storage cmd = commands[commandHash];
        require(!cmd.executed, "SofieOSAdapter: Already executed");
        require(block.timestamp >= cmd.executeAfter, "SofieOSAdapter: Too early");

        cmd.executed = true;
        cmd.resultHash = resultHash;

        emit OSCommandExecuted(commandHash, resultHash);
    }

    // ============ OS Node Management ============
    
    function authorizeOSNode(address node) external onlyGovernance {
        authorizedOSNodes[node] = true;
    }

    function revokeOSNode(address node) external onlyGovernance {
        authorizedOSNodes[node] = false;
    }

    function setHeartbeatTimeout(uint256 timeout) external onlyGovernance {
        heartbeatTimeout = timeout;
    }

    // ============ View Functions ============
    
    function getDevice(bytes32 deviceHash) external view returns (Device memory) {
        return devices[deviceHash];
    }

    function getOwnerDevices(address owner) external view returns (bytes32[] memory) {
        return ownerDevices[owner];
    }

    function isDeviceActive(bytes32 deviceHash) external view returns (bool) {
        Device memory device = devices[deviceHash];
        return device.active && (block.timestamp - device.lastHeartbeat) <= heartbeatTimeout;
    }

    function getPermissionCache(address patient) external view returns (PermissionCache memory) {
        return permissionCaches[patient];
    }

    function getCommand(bytes32 commandHash) external view returns (OSCommand memory) {
        return commands[commandHash];
    }
}
