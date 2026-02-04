// SPDX-License-Identifier: MIT
/**
 * @title ITerratoneProtocol
 * @notice Interface for Terratone 9D breathwork and frequency therapy
 * @dev Integration with 9-dimensional biofield tuning protocols
 */
pragma solidity ^0.8.24;

interface ITerratoneProtocol {
    /// @notice 9D frequency dimensions
    enum Dimension {
        Physical,       // 1D - Cellular resonance
        Emotional,      // 2D - Heart coherence
        Mental,         // 3D - Brainwave entrainment
        Energetic,      // 4D - Meridian activation
        Sonic,          // 5D - Harmonic intonation
        Sacred,         // 6D - Geometric patterns
        Cosmic,         // 7D - Planetary frequencies
        Source,         // 8D - Unity consciousness
        Integral        // 9D - Complete field integration
    }

    /// @notice Therapy session types
    enum TherapyType {
        Breathwork,
        SoundBath,
        FrequencyImprinting,
        ChakraTuning,
        BrainwaveSync,
        CellularDetox,
        TraumaRelease,
        SpiritualUpgrade
    }

    /// @notice Frequency protocol record (hash-only on-chain)
    struct FrequencyProtocol {
        bytes32 protocolHash;       // Hash of full protocol spec
        TherapyType therapyType;
        Dimension[] dimensions;
        uint256 frequencyBase;      // Base frequency in Hz (x100 for precision)
        uint256 duration;           // Recommended session time
        address practitioner;
        bool isVerified;
        uint256 createdAt;
    }

    /// @notice Therapy session record
    struct TherapySession {
        bytes32 sessionHash;
        bytes32 protocolHash;
        bytes32 recipientIdentity;
        uint256 startTime;
        uint256 actualDuration;
        bytes32 beforeStateHash;    // Pre-session biofield scan
        bytes32 afterStateHash;     // Post-session biofield scan
        bool isComplete;
    }

    /// @notice Emitted when frequency protocol is registered
    event ProtocolRegistered(
        bytes32 indexed protocolHash,
        TherapyType therapyType,
        address indexed practitioner,
        uint256 frequencyBase
    );

    /// @notice Emitted when therapy session begins
    event SessionStarted(
        bytes32 indexed sessionHash,
        bytes32 indexed protocolHash,
        bytes32 indexed recipientIdentity,
        uint256 startTime
    );

    /// @notice Emitted when therapy session completes
    event SessionCompleted(
        bytes32 indexed sessionHash,
        uint256 actualDuration,
        bytes32 afterStateHash
    );

    /// @notice Register a new frequency protocol
    /// @param _protocolHash Hash of protocol specification
    /// @param _therapyType Type of therapy
    /// @param _dimensions Array of dimensions used
    /// @param _frequencyBase Base frequency (Hz x 100)
    /// @param _duration Recommended session duration
    function registerProtocol(
        bytes32 _protocolHash,
        TherapyType _therapyType,
        Dimension[] calldata _dimensions,
        uint256 _frequencyBase,
        uint256 _duration
    ) external returns (bool);

    /// @notice Start a therapy session
    /// @param _sessionHash Unique session identifier
    /// @param _protocolHash Protocol being used
    /// @param _recipientIdentity Patient's sovereign identity
    /// @param _beforeStateHash Pre-session state hash
    function startSession(
        bytes32 _sessionHash,
        bytes32 _protocolHash,
        bytes32 _recipientIdentity,
        bytes32 _beforeStateHash
    ) external returns (bool);

    /// @notice Complete a therapy session
    /// @param _sessionHash Session to complete
    /// @param _actualDuration Actual session duration
    /// @param _afterStateHash Post-session state hash
    function completeSession(
        bytes32 _sessionHash,
        uint256 _actualDuration,
        bytes32 _afterStateHash
    ) external returns (bool);

    /// @notice Get protocol details
    /// @param _protocolHash Protocol identifier
    function getProtocol(
        bytes32 _protocolHash
    ) external view returns (FrequencyProtocol memory);

    /// @notice Get session details
    /// @param _sessionHash Session identifier
    function getSession(
        bytes32 _sessionHash
    ) external view returns (TherapySession memory);

    /// @notice Verify protocol is registered and valid
    /// @param _protocolHash Protocol to verify
    function isProtocolVerified(bytes32 _protocolHash) external view returns (bool);

    /// @notice Get recommended frequency for dimension
    /// @param _dimension The 9D dimension
    function getDimensionFrequency(Dimension _dimension) external view returns (uint256 frequencyHz);
}
