// SPDX-License-Identifier: MIT
/**
 * @title TerratoneAdapter
 * @notice Bridge for Terratone 9D breathwork and frequency therapy
 * @dev Implements ITerratoneProtocol for 9-dimensional biofield tuning
 */
pragma solidity ^0.8.24;

import {ITerratoneProtocol} from "../interfaces/ITerratoneProtocol.sol";

contract TerratoneAdapter is ITerratoneProtocol {
    
    // ============ Storage ============
    
    address public sovereignIdentity;
    address public accessGovernor;
    address public auditTrail;
    
    // Protocol hash => protocol data
    mapping(bytes32 => FrequencyProtocol) private protocols;
    
    // Session hash => session data
    mapping(bytes32 => TherapySession) private sessions;
    
    // User identity => session hashes
    mapping(bytes32 => bytes32[]) private userSessions;
    
    // Practitioner => isAuthorized
    mapping(address => bool) public authorizedPractitioners;
    
    // Dimension frequencies (Hz x 100 for precision)
    mapping(Dimension => uint256) public dimensionFrequencies;
    
    // ============ Modifiers ============
    
    modifier onlyPractitioner() {
        require(authorizedPractitioners[msg.sender], "TerratoneAdapter: Not authorized");
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
        
        // Initialize 9D frequencies (in Hz x 100)
        dimensionFrequencies[Dimension.Physical] = 43200;      // 432 Hz - cellular
        dimensionFrequencies[Dimension.Emotional] = 52800;     // 528 Hz - heart
        dimensionFrequencies[Dimension.Mental] = 85200;        // 852 Hz - mental clarity
        dimensionFrequencies[Dimension.Energetic] = 63900;     // 639 Hz - energetic
        dimensionFrequencies[Dimension.Sonic] = 74100;         // 741 Hz - sonic
        dimensionFrequencies[Dimension.Sacred] = 39600;        // 396 Hz - sacred
        dimensionFrequencies[Dimension.Cosmic] = 96300;        // 963 Hz - cosmic
        dimensionFrequencies[Dimension.Source] = 111000;       // 1110 Hz - source
        dimensionFrequencies[Dimension.Integral] = 17400;      // 174 Hz - integral
    }
    
    // ============ Admin Functions ============
    
    function authorizePractitioner(address practitioner) external {
        require(
            msg.sender == accessGovernor || msg.sender == sovereignIdentity,
            "TerratoneAdapter: Not authorized"
        );
        authorizedPractitioners[practitioner] = true;
    }
    
    function revokePractitioner(address practitioner) external {
        require(
            msg.sender == accessGovernor || msg.sender == sovereignIdentity,
            "TerratoneAdapter: Not authorized"
        );
        authorizedPractitioners[practitioner] = false;
    }
    
    // ============ ITerratoneProtocol Implementation ============
    
    function registerProtocol(
        bytes32 _protocolHash,
        TherapyType _therapyType,
        Dimension[] calldata _dimensions,
        uint256 _frequencyBase,
        uint256 _duration
    ) external override onlyPractitioner returns (bool) {
        require(_protocolHash != bytes32(0), "TerratoneAdapter: Invalid protocol hash");
        require(protocols[_protocolHash].protocolHash == bytes32(0), "TerratoneAdapter: Protocol exists");
        
        FrequencyProtocol memory protocol = FrequencyProtocol({
            protocolHash: _protocolHash,
            therapyType: _therapyType,
            dimensions: _dimensions,
            frequencyBase: _frequencyBase,
            duration: _duration,
            practitioner: msg.sender,
            isVerified: true,
            createdAt: block.timestamp
        });
        
        protocols[_protocolHash] = protocol;
        
        emit ProtocolRegistered(
            _protocolHash,
            _therapyType,
            msg.sender,
            _frequencyBase
        );
        
        return true;
    }
    
    function startSession(
        bytes32 _sessionHash,
        bytes32 _protocolHash,
        bytes32 _recipientIdentity,
        bytes32 _beforeStateHash
    ) external override onlyPractitioner returns (bool) {
        require(_sessionHash != bytes32(0), "TerratoneAdapter: Invalid session hash");
        require(protocols[_protocolHash].protocolHash != bytes32(0), "TerratoneAdapter: Protocol not found");
        require(sessions[_sessionHash].sessionHash == bytes32(0), "TerratoneAdapter: Session exists");
        
        TherapySession memory session = TherapySession({
            sessionHash: _sessionHash,
            protocolHash: _protocolHash,
            recipientIdentity: _recipientIdentity,
            startTime: block.timestamp,
            actualDuration: 0,
            beforeStateHash: _beforeStateHash,
            afterStateHash: bytes32(0),
            isComplete: false
        });
        
        sessions[_sessionHash] = session;
        
        emit SessionStarted(
            _sessionHash,
            _protocolHash,
            _recipientIdentity,
            block.timestamp
        );
        
        return true;
    }
    
    function completeSession(
        bytes32 _sessionHash,
        uint256 _actualDuration,
        bytes32 _afterStateHash
    ) external override onlyPractitioner returns (bool) {
        TherapySession storage session = sessions[_sessionHash];
        require(session.sessionHash != bytes32(0), "TerratoneAdapter: Session not found");
        require(!session.isComplete, "TerratoneAdapter: Already complete");
        
        session.actualDuration = _actualDuration;
        session.afterStateHash = _afterStateHash;
        session.isComplete = true;
        
        userSessions[session.recipientIdentity].push(_sessionHash);
        
        emit SessionCompleted(_sessionHash, _actualDuration, _afterStateHash);
        
        return true;
    }
    
    function getProtocol(
        bytes32 _protocolHash
    ) external view override returns (FrequencyProtocol memory) {
        return protocols[_protocolHash];
    }
    
    function getSession(
        bytes32 _sessionHash
    ) external view override returns (TherapySession memory) {
        return sessions[_sessionHash];
    }
    
    function isProtocolVerified(bytes32 _protocolHash) external view override returns (bool) {
        return protocols[_protocolHash].isVerified;
    }
    
    function getDimensionFrequency(Dimension _dimension) external view override returns (uint256 frequencyHz) {
        return dimensionFrequencies[_dimension];
    }
    
    // ============ Additional Functions ============
    
    function getUserSessions(
        bytes32 _userIdentity
    ) external view returns (bytes32[] memory) {
        return userSessions[_userIdentity];
    }
    
    function updateDimensionFrequency(Dimension _dimension, uint256 _frequency) external {
        require(
            msg.sender == accessGovernor || msg.sender == sovereignIdentity,
            "TerratoneAdapter: Not authorized"
        );
        dimensionFrequencies[_dimension] = _frequency;
    }
}
