// SPDX-License-Identifier: MIT
// Pillar-1: Geo-fenced access rights using location hashes
// Pillar-2: First Principles: Location is a permission vector
// Pillar-3: Genius Channeled - Buckminster Fuller (geodesic spheres)
// Pillar-4: Geographic sovereignty as strategic moat
// Pillar-5: Location-based consent management
// Pillar-6: OODA loops for geo-fence decisions
// Pillar-7: Build for location privacy

pragma solidity ^0.8.24;

import "../SovereignIdentity.sol";
import "../AccessGovernor.sol";
import "../AuditTrail.sol";

/**
 * @title MapAdapter
 * @dev Geographic/location layer adapter for Terracare
 *      - Geo-fenced access rights
 *      - Location-based consent management
 *      - Provider access valid only in specific radius
 *      - Regional data sovereignty compliance
 */
contract MapAdapter {
    // ============ Structs ============
    
    struct GeoFence {
        bytes32 fenceId;
        address owner;
        int256 centerLat;           // Latitude * 1e6 (microdegrees)
        int256 centerLng;           // Longitude * 1e6 (microdegrees)
        uint256 radiusMeters;       // Radius in meters
        uint256 createdAt;
        uint256 expiresAt;
        bool active;
        bytes32 purposeHash;        // Purpose of geo-fence
    }

    struct LocationConsent {
        address patient;
        address grantee;
        bytes32 fenceId;
        uint256 grantedAt;
        uint256 expiresAt;
        bool active;
        bytes32 consentTermsHash;   // Terms of location-based access
    }

    struct LocationAttestation {
        bytes32 attestationHash;
        address subject;
        int256 lat;                 // Latitude * 1e6
        int256 lng;                 // Longitude * 1e6
        uint256 timestamp;
        uint256 accuracyMeters;
        bytes32 deviceHash;
        address attestor;
    }

    struct RegionalRule {
        bytes32 regionHash;         // Hash of region identifier
        bool dataResidencyRequired; // Data must stay in region
        bytes32 allowedDataCenters; // Hash of allowed DC list
        bool active;
    }

    // ============ State ============
    
    SovereignIdentity public identity;
    AccessGovernor public accessGovernor;
    AuditTrail public auditTrail;
    
    address public governance;
    
    // Fence ID => GeoFence
    mapping(bytes32 => GeoFence) public geoFences;
    mapping(address => bytes32[]) public ownerFences;
    
    // Consent ID => LocationConsent (consent ID = hash of patient + grantee + fence)
    mapping(bytes32 => LocationConsent) public locationConsents;
    mapping(address => bytes32[]) public patientLocationConsents;
    
    // Attestation hash => LocationAttestation
    mapping(bytes32 => LocationAttestation) public attestations;
    
    // Region hash => RegionalRule
    mapping(bytes32 => RegionalRule) public regionalRules;
    
    // Authorized location oracles
    mapping(address => bool) public locationOracles;
    
    // Earth's radius in meters for distance calculations
    uint256 private constant EARTH_RADIUS = 6371000;

    // ============ Events ============
    
    event GeoFenceCreated(
        bytes32 indexed fenceId,
        address indexed owner,
        int256 lat,
        int256 lng,
        uint256 radius
    );
    
    event LocationConsentGranted(
        bytes32 indexed consentId,
        address indexed patient,
        address indexed grantee,
        bytes32 fenceId
    );
    
    event LocationAttested(
        bytes32 indexed attestationHash,
        address indexed subject,
        int256 lat,
        int256 lng
    );
    
    event RegionalRuleSet(
        bytes32 indexed regionHash,
        bool dataResidencyRequired
    );

    // ============ Modifiers ============
    
    modifier onlyGovernance() {
        require(msg.sender == governance, "MapAdapter: Not governance");
        _;
    }

    modifier onlyLocationOracle() {
        require(
            locationOracles[msg.sender] || msg.sender == governance,
            "MapAdapter: Not location oracle"
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

    // ============ Geo-Fence Management ============
    
    /**
     * @dev Create geo-fenced area
     */
    function createGeoFence(
        bytes32 fenceId,
        int256 centerLat,
        int256 centerLng,
        uint256 radiusMeters,
        uint256 validityDays,
        bytes32 purposeHash
    ) external {
        require(geoFences[fenceId].createdAt == 0, "MapAdapter: Fence exists");
        require(
            identity.getProfile(msg.sender).status == SovereignIdentity.IdentityStatus.Active,
            "MapAdapter: Not active"
        );

        geoFences[fenceId] = GeoFence({
            fenceId: fenceId,
            owner: msg.sender,
            centerLat: centerLat,
            centerLng: centerLng,
            radiusMeters: radiusMeters,
            createdAt: block.timestamp,
            expiresAt: block.timestamp + (validityDays * 1 days),
            active: true,
            purposeHash: purposeHash
        });

        ownerFences[msg.sender].push(fenceId);

        // Link identity
        if (identity.getSystemIdentity(msg.sender, SovereignIdentity.SystemType.MapSystem).systemId == bytes32(0)) {
            identity.linkSystem(msg.sender, SovereignIdentity.SystemType.MapSystem, fenceId);
        }

        auditTrail.createEntry(
            msg.sender,
            SovereignIdentity.SystemType.MapSystem,
            keccak256("GEOFENCE_CREATED"),
            fenceId,
            new bytes32[](0)
        );

        emit GeoFenceCreated(fenceId, msg.sender, centerLat, centerLng, radiusMeters);
    }

    /**
     * @dev Deactivate geo-fence
     */
    function deactivateGeoFence(bytes32 fenceId) external {
        require(
            geoFences[fenceId].owner == msg.sender || msg.sender == governance,
            "MapAdapter: Not owner"
        );
        geoFences[fenceId].active = false;
    }

    // ============ Location Consent ============
    
    /**
     * @dev Grant location-based consent
     * Provider access valid only in specific geo-fence
     */
    function grantLocationConsent(
        address grantee,
        bytes32 fenceId,
        uint256 validityDays,
        bytes32 consentTermsHash
    ) external {
        require(geoFences[fenceId].active, "MapAdapter: Fence not active");
        require(
            identity.getProfile(msg.sender).status == SovereignIdentity.IdentityStatus.Active,
            "MapAdapter: Not active"
        );

        bytes32 consentId = keccak256(abi.encodePacked(msg.sender, grantee, fenceId));

        locationConsents[consentId] = LocationConsent({
            patient: msg.sender,
            grantee: grantee,
            fenceId: fenceId,
            grantedAt: block.timestamp,
            expiresAt: block.timestamp + (validityDays * 1 days),
            active: true,
            consentTermsHash: consentTermsHash
        });

        patientLocationConsents[msg.sender].push(consentId);

        auditTrail.createEntry(
            msg.sender,
            SovereignIdentity.SystemType.MapSystem,
            keccak256("LOCATION_CONSENT_GRANTED"),
            consentId,
            new bytes32[](0)
        );

        emit LocationConsentGranted(consentId, msg.sender, grantee, fenceId);
    }

    /**
     * @dev Revoke location consent
     */
    function revokeLocationConsent(bytes32 consentId) external {
        LocationConsent storage consent = locationConsents[consentId];
        require(
            consent.patient == msg.sender || msg.sender == governance,
            "MapAdapter: Not authorized"
        );
        consent.active = false;
    }

    // ============ Location Attestation ============
    
    /**
     * @dev Attest location - called by authorized oracle
     */
    function attestLocation(
        bytes32 attestationHash,
        address subject,
        int256 lat,
        int256 lng,
        uint256 accuracyMeters,
        bytes32 deviceHash
    ) external onlyLocationOracle {
        attestations[attestationHash] = LocationAttestation({
            attestationHash: attestationHash,
            subject: subject,
            lat: lat,
            lng: lng,
            timestamp: block.timestamp,
            accuracyMeters: accuracyMeters,
            deviceHash: deviceHash,
            attestor: msg.sender
        });

        auditTrail.createEntry(
            subject,
            SovereignIdentity.SystemType.MapSystem,
            keccak256("LOCATION_ATTESTED"),
            attestationHash,
            new bytes32[](0)
        );

        emit LocationAttested(attestationHash, subject, lat, lng);
    }

    // ============ Regional Rules ============
    
    /**
     * @dev Set regional data sovereignty rules
     */
    function setRegionalRule(
        bytes32 regionHash,
        bool dataResidencyRequired,
        bytes32 allowedDataCenters
    ) external onlyGovernance {
        regionalRules[regionHash] = RegionalRule({
            regionHash: regionHash,
            dataResidencyRequired: dataResidencyRequired,
            allowedDataCenters: allowedDataCenters,
            active: true
        });

        auditTrail.createEntry(
            address(0),
            SovereignIdentity.SystemType.MapSystem,
            keccak256("REGIONAL_RULE_SET"),
            regionHash,
            new bytes32[](0)
        );

        emit RegionalRuleSet(regionHash, dataResidencyRequired);
    }

    // ============ Verification ============
    
    /**
     * @dev Check if location is within geo-fence
     */
    function isWithinFence(
        bytes32 fenceId,
        int256 lat,
        int256 lng
    ) external view returns (bool) {
        GeoFence memory fence = geoFences[fenceId];
        if (!fence.active || fence.expiresAt < block.timestamp) return false;

        uint256 distance = _calculateDistance(
            fence.centerLat,
            fence.centerLng,
            lat,
            lng
        );

        return distance <= fence.radiusMeters;
    }

    /**
     * @dev Verify location consent is valid for current location
     */
    function verifyLocationConsent(
        bytes32 consentId,
        bytes32 locationAttestation
    ) external view returns (bool valid) {
        LocationConsent memory consent = locationConsents[consentId];
        if (!consent.active || consent.expiresAt < block.timestamp) return false;

        LocationAttestation memory attestation = attestations[locationAttestation];
        if (attestation.timestamp == 0) return false;
        if (attestation.timestamp < block.timestamp - 1 hours) return false; // Stale

        GeoFence memory fence = geoFences[consent.fenceId];
        if (!fence.active) return false;

        uint256 distance = _calculateDistance(
            fence.centerLat,
            fence.centerLng,
            attestation.lat,
            attestation.lng
        );

        return distance <= fence.radiusMeters;
    }

    // ============ Oracle Management ============
    
    function authorizeOracle(address oracle) external onlyGovernance {
        locationOracles[oracle] = true;
    }

    function revokeOracle(address oracle) external onlyGovernance {
        locationOracles[oracle] = false;
    }

    // ============ View Functions ============
    
    function getGeoFence(bytes32 fenceId) external view returns (GeoFence memory) {
        return geoFences[fenceId];
    }

    function getLocationConsent(bytes32 consentId) external view returns (LocationConsent memory) {
        return locationConsents[consentId];
    }

    function getAttestation(bytes32 attestationHash) external view returns (LocationAttestation memory) {
        return attestations[attestationHash];
    }

    function getRegionalRule(bytes32 regionHash) external view returns (RegionalRule memory) {
        return regionalRules[regionHash];
    }

    function getPatientConsents(address patient) external view returns (bytes32[] memory) {
        return patientLocationConsents[patient];
    }

    // ============ Distance Calculation ============
    
    /**
     * @dev Calculate distance between two points using Haversine formula
     * Coordinates are in microdegrees (degrees * 1e6)
     * Returns distance in meters
     */
    function _calculateDistance(
        int256 lat1,
        int256 lng1,
        int256 lat2,
        int256 lng2
    ) internal pure returns (uint256) {
        // Convert to radians (with 1e6 scaling)
        int256 dLat = (lat2 - lat1) * 314159265359 / (180 * 1000000 * 100000000);
        int256 dLng = (lng2 - lng1) * 314159265359 / (180 * 1000000 * 100000000);

        int256 a = (_sin(dLat / 2) ** 2 + 
                    _cos(lat1 * 314159265359 / (180 * 1000000 * 100000000)) * 
                    _cos(lat2 * 314159265359 / (180 * 1000000 * 100000000)) * 
                    _sin(dLng / 2) ** 2);

        int256 c = 2 * _atan2(_sqrt(a), _sqrt(1e18 - a));

        return uint256(EARTH_RADIUS * uint256(c) / 1e9);
    }

    // Simplified trig functions for Solidity (using approximations)
    function _sin(int256 x) internal pure returns (int256) {
        // Taylor series approximation for sin(x)
        // sin(x) ≈ x - x^3/6 + x^5/120 - x^7/5040
        int256 x2 = x * x / 1e9;
        int256 x3 = x2 * x / 1e9;
        int256 x5 = x3 * x2 / 1e9;
        int256 x7 = x5 * x2 / 1e9;
        return x - x3 / 6 + x5 / 120 - x7 / 5040;
    }

    function _cos(int256 x) internal pure returns (int256) {
        // cos(x) = sin(x + π/2)
        return _sin(x + 1570796327); // π/2 * 1e9
    }

    function _sqrt(int256 x) internal pure returns (int256) {
        if (x < 0) return 0;
        int256 z = (x + 1) / 2;
        int256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    function _atan2(int256 y, int256 x) internal pure returns (int256) {
        // Simplified atan2 approximation
        // For precise calculations, consider using a library
        if (x > 0) return _atan(y / x);
        if (x < 0 && y >= 0) return _atan(y / x) + 3141592654;
        if (x < 0 && y < 0) return _atan(y / x) - 3141592654;
        if (x == 0 && y > 0) return 1570796327;
        if (x == 0 && y < 0) return -1570796327;
        return 0;
    }

    function _atan(int256 x) internal pure returns (int256) {
        // Taylor series for atan(x)
        // atan(x) ≈ x - x^3/3 + x^5/5 - x^7/7 (for |x| <= 1)
        if (x > 1e9) return 1570796327 - _atan(1e18 / x);
        if (x < -1e9) return -1570796327 - _atan(1e18 / x);
        
        int256 x2 = x * x / 1e9;
        int256 x3 = x2 * x / 1e9;
        int256 x5 = x3 * x2 / 1e9;
        int256 x7 = x5 * x2 / 1e9;
        
        return x - x3 / 3 + x5 / 5 - x7 / 7;
    }
}
