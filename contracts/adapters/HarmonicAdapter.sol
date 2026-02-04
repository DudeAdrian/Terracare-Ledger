// SPDX-License-Identifier: MIT
/**
 * @title HarmonicAdapter
 * @notice Bridge for Harmonic biofeedback devices and sessions
 * @dev Implements IHarmonicDevice for soulbound device certifications
 */
pragma solidity ^0.8.24;

import {IHarmonicDevice} from "../interfaces/IHarmonicDevice.sol";

contract HarmonicAdapter is IHarmonicDevice {
    
    // ============ Storage ============
    
    address public sovereignIdentity;
    address public accessGovernor;
    address public auditTrail;
    
    // Device hash => certification
    mapping(bytes32 => DeviceCertification) private certifications;
    
    // User identity => session hashes
    mapping(bytes32 => bytes32[]) private userSessions;
    
    // Session hash => session data
    mapping(bytes32 => SessionRecord) private sessions;
    
    // Authorized certifiers
    mapping(address => bool) public certifiers;
    
    // ============ Modifiers ============
    
    modifier onlyCertifier() {
        require(certifiers[msg.sender], "HarmonicAdapter: Not certifier");
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
        certifiers[msg.sender] = true; // Deployer is initial certifier
    }
    
    // ============ Admin Functions ============
    
    function addCertifier(address _certifier) external {
        require(certifiers[msg.sender], "HarmonicAdapter: Not authorized");
        certifiers[_certifier] = true;
    }
    
    function removeCertifier(address _certifier) external {
        require(certifiers[msg.sender], "HarmonicAdapter: Not authorized");
        certifiers[_certifier] = false;
    }
    
    // ============ IHarmonicDevice Implementation ============
    
    function certifyDevice(
        bytes32 _deviceHash,
        DeviceType _deviceType,
        CertificationTier _tier,
        uint256 _expiresAt,
        bytes32 _firmwareHash
    ) external override onlyCertifier returns (bool) {
        require(_deviceHash != bytes32(0), "HarmonicAdapter: Invalid device hash");
        require(certifications[_deviceHash].deviceHash == bytes32(0), "HarmonicAdapter: Already certified");
        
        DeviceCertification memory cert = DeviceCertification({
            deviceHash: _deviceHash,
            deviceType: _deviceType,
            tier: _tier,
            manufacturer: msg.sender,
            certifiedAt: block.timestamp,
            expiresAt: _expiresAt,
            isRevoked: false,
            firmwareHash: _firmwareHash
        });
        
        certifications[_deviceHash] = cert;
        
        emit DeviceCertified(
            _deviceHash,
            _deviceType,
            _tier,
            msg.sender,
            _expiresAt
        );
        
        return true;
    }
    
    function revokeCertification(
        bytes32 _deviceHash,
        bytes32 _reasonHash
    ) external override onlyCertifier {
        DeviceCertification storage cert = certifications[_deviceHash];
        require(cert.deviceHash != bytes32(0), "HarmonicAdapter: Device not certified");
        require(!cert.isRevoked, "HarmonicAdapter: Already revoked");
        
        cert.isRevoked = true;
        
        emit CertificationRevoked(_deviceHash, _reasonHash, block.timestamp);
    }
    
    function recordSession(
        bytes32 _sessionHash,
        bytes32 _deviceHash,
        bytes32 _userIdentity,
        uint256 _duration,
        bytes32 _metricsHash
    ) external override returns (bool) {
        require(_sessionHash != bytes32(0), "HarmonicAdapter: Invalid session hash");
        require(isDeviceCertified(_deviceHash), "HarmonicAdapter: Device not certified");
        require(sessions[_sessionHash].sessionHash == bytes32(0), "HarmonicAdapter: Session exists");
        
        SessionRecord memory session = SessionRecord({
            sessionHash: _sessionHash,
            deviceHash: _deviceHash,
            userIdentity: _userIdentity,
            startTime: block.timestamp,
            duration: _duration,
            metricsHash: _metricsHash
        });
        
        sessions[_sessionHash] = session;
        userSessions[_userIdentity].push(_sessionHash);
        
        emit SessionRecorded(
            _sessionHash,
            _deviceHash,
            _userIdentity,
            block.timestamp
        );
        
        return true;
    }
    
    function isDeviceCertified(bytes32 _deviceHash) public view override returns (bool) {
        DeviceCertification storage cert = certifications[_deviceHash];
        if (cert.deviceHash == bytes32(0)) return false;
        if (cert.isRevoked) return false;
        if (cert.expiresAt != 0 && block.timestamp > cert.expiresAt) return false;
        return true;
    }
    
    function getCertification(
        bytes32 _deviceHash
    ) external view override returns (DeviceCertification memory) {
        return certifications[_deviceHash];
    }
    
    function getUserSessions(
        bytes32 _userIdentity
    ) external view override returns (bytes32[] memory sessionHashes) {
        return userSessions[_userIdentity];
    }
    
    // ============ View Functions ============
    
    function getSession(bytes32 _sessionHash) external view returns (SessionRecord memory) {
        return sessions[_sessionHash];
    }
}
