// SPDX-License-Identifier: MIT
/**
 * @title MapAdapter
 * @notice Bridge for geographic sovereignty and geo-fencing
 * @dev Manages location-based access and territorial boundaries
 */
pragma solidity ^0.8.24;

contract MapAdapter {
    
    // ============ Types ============
    
    enum ZoneType {
        Private,        // Personal space
        Clinical,       // Healthcare facility
        Research,       // Research zone
        Sacred,         // Protected spiritual site
        Restricted      // No-access zone
    }
    
    enum GeoAction {
        Enter,
        Exit,
        Remain
    }
    
    // Geohash precision levels (character count)
    // 6 chars = ~1.2km, 7 = ~150m, 8 = ~20m, 9 = ~2.4m
    struct GeoZone {
        bytes32 zoneId;
        string geohashPrefix;   // Geohash prefix for zone
        uint8 precision;        // Number of characters
        ZoneType zoneType;
        address owner;
        bool isActive;
        uint256 createdAt;
        // Boundary hashes (for complex shapes)
        bytes32 boundaryHash;   // Hash of full boundary data
    }
    
    struct GeoEvent {
        bytes32 eventId;
        bytes32 zoneId;
        bytes32 identityHash;
        GeoAction action;
        bytes32 locationHash;   // Precise location hash
        uint256 timestamp;
        bytes32 deviceHash;     // Device that recorded
    }
    
    struct AccessRule {
        bytes32 zoneId;
        bytes32 identityHash;
        bool isAllowed;
        uint256 expiresAt;
        bytes32 ruleHash;       // Terms of access
    }
    
    // ============ Storage ============
    
    address public sovereignIdentity;
    address public accessGovernor;
    address public auditTrail;
    
    // Zone ID => zone data
    mapping(bytes32 => GeoZone) public zones;
    
    // Event ID => event data
    mapping(bytes32 => GeoEvent) public geoEvents;
    
    // Identity => current zone
    mapping(bytes32 => bytes32) public currentZone;
    
    // Access rules: zone => identity => rule
    mapping(bytes32 => mapping(bytes32 => AccessRule)) public accessRules;
    
    // Identity => event IDs (history)
    mapping(bytes32 => bytes32[]) public identityGeoHistory;
    
    // Authorized zone managers
    mapping(address => bool) public zoneManagers;
    
    // ============ Events ============
    
    event ZoneCreated(
        bytes32 indexed zoneId,
        string geohashPrefix,
        ZoneType zoneType,
        address owner,
        uint256 timestamp
    );
    
    event GeoEventRecorded(
        bytes32 indexed eventId,
        bytes32 indexed zoneId,
        bytes32 indexed identityHash,
        GeoAction action,
        uint256 timestamp
    );
    
    event AccessRuleSet(
        bytes32 indexed zoneId,
        bytes32 indexed identityHash,
        bool isAllowed,
        uint256 expiresAt
    );
    
    event ZoneDeactivated(bytes32 indexed zoneId, uint256 timestamp);
    
    // ============ Modifiers ============
    
    modifier onlyZoneManager() {
        require(zoneManagers[msg.sender], "MapAdapter: Not zone manager");
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
        zoneManagers[msg.sender] = true;
    }
    
    // ============ Admin Functions ============
    
    function addZoneManager(address manager) external {
        require(
            msg.sender == accessGovernor || msg.sender == sovereignIdentity,
            "MapAdapter: Not authorized"
        );
        zoneManagers[manager] = true;
    }
    
    function removeZoneManager(address manager) external {
        require(
            msg.sender == accessGovernor || msg.sender == sovereignIdentity,
            "MapAdapter: Not authorized"
        );
        zoneManagers[manager] = false;
    }
    
    // ============ Zone Management ============
    
    function createZone(
        bytes32 _zoneId,
        string calldata _geohashPrefix,
        uint8 _precision,
        ZoneType _zoneType,
        bytes32 _boundaryHash
    ) external onlyZoneManager returns (bool) {
        require(_zoneId != bytes32(0), "MapAdapter: Invalid zone ID");
        require(zones[_zoneId].zoneId == bytes32(0), "MapAdapter: Zone exists");
        require(_precision >= 4 && _precision <= 12, "MapAdapter: Invalid precision");
        
        GeoZone memory zone = GeoZone({
            zoneId: _zoneId,
            geohashPrefix: _geohashPrefix,
            precision: _precision,
            zoneType: _zoneType,
            owner: msg.sender,
            isActive: true,
            createdAt: block.timestamp,
            boundaryHash: _boundaryHash
        });
        
        zones[_zoneId] = zone;
        
        emit ZoneCreated(_zoneId, _geohashPrefix, _zoneType, msg.sender, block.timestamp);
        
        return true;
    }
    
    function deactivateZone(bytes32 _zoneId) external {
        GeoZone storage zone = zones[_zoneId];
        require(
            zone.owner == msg.sender || 
            msg.sender == accessGovernor ||
            msg.sender == sovereignIdentity,
            "MapAdapter: Not authorized"
        );
        zone.isActive = false;
        
        emit ZoneDeactivated(_zoneId, block.timestamp);
    }
    
    // ============ Access Rules ============
    
    function setAccessRule(
        bytes32 _zoneId,
        bytes32 _identityHash,
        bool _isAllowed,
        uint256 _expiresAt,
        bytes32 _ruleHash
    ) external {
        GeoZone storage zone = zones[_zoneId];
        require(
            zone.owner == msg.sender || 
            msg.sender == accessGovernor,
            "MapAdapter: Not authorized"
        );
        
        AccessRule memory rule = AccessRule({
            zoneId: _zoneId,
            identityHash: _identityHash,
            isAllowed: _isAllowed,
            expiresAt: _expiresAt,
            ruleHash: _ruleHash
        });
        
        accessRules[_zoneId][_identityHash] = rule;
        
        emit AccessRuleSet(_zoneId, _identityHash, _isAllowed, _expiresAt);
    }
    
    function checkAccess(
        bytes32 _zoneId,
        bytes32 _identityHash
    ) external view returns (bool) {
        GeoZone storage zone = zones[_zoneId];
        if (!zone.isActive) return false;
        
        AccessRule storage rule = accessRules[_zoneId][_identityHash];
        if (rule.expiresAt != 0 && block.timestamp > rule.expiresAt) return false;
        
        return rule.isAllowed;
    }
    
    // ============ Geo Event Recording ============
    
    function recordGeoEvent(
        bytes32 _eventId,
        bytes32 _zoneId,
        bytes32 _identityHash,
        GeoAction _action,
        bytes32 _locationHash,
        bytes32 _deviceHash
    ) external onlyZoneManager returns (bool) {
        require(_eventId != bytes32(0), "MapAdapter: Invalid event ID");
        require(zones[_zoneId].isActive, "MapAdapter: Zone not active");
        require(geoEvents[_eventId].eventId == bytes32(0), "MapAdapter: Event exists");
        
        GeoEvent memory event_ = GeoEvent({
            eventId: _eventId,
            zoneId: _zoneId,
            identityHash: _identityHash,
            action: _action,
            locationHash: _locationHash,
            timestamp: block.timestamp,
            deviceHash: _deviceHash
        });
        
        geoEvents[_eventId] = event_;
        identityGeoHistory[_identityHash].push(_eventId);
        
        if (_action == GeoAction.Enter) {
            currentZone[_identityHash] = _zoneId;
        } else if (_action == GeoAction.Exit) {
            currentZone[_identityHash] = bytes32(0);
        }
        
        emit GeoEventRecorded(_eventId, _zoneId, _identityHash, _action, block.timestamp);
        
        return true;
    }
    
    // ============ View Functions ============
    
    function getZone(bytes32 _zoneId) external view returns (GeoZone memory) {
        return zones[_zoneId];
    }
    
    function getGeoEvent(bytes32 _eventId) external view returns (GeoEvent memory) {
        return geoEvents[_eventId];
    }
    
    function getIdentityHistory(bytes32 _identityHash) external view returns (bytes32[] memory) {
        return identityGeoHistory[_identityHash];
    }
    
    function getCurrentZone(bytes32 _identityHash) external view returns (bytes32) {
        return currentZone[_identityHash];
    }
    
    function getAccessRule(
        bytes32 _zoneId,
        bytes32 _identityHash
    ) external view returns (AccessRule memory) {
        return accessRules[_zoneId][_identityHash];
    }
}
