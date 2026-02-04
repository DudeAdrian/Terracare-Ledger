// SPDX-License-Identifier: MIT
/**
 * @title IHarmonicDevice
 * @notice Interface for Harmonic biofeedback devices
 * @dev Soulbound device certifications and session management
 */
pragma solidity ^0.8.24;

interface IHarmonicDevice {
    /// @notice Device types in the Harmonic ecosystem
    enum DeviceType {
        HeartRateMonitor,
        BreathingCoach,
        MeditationHeadset,
        SleepTracker,
        StressMonitor,
        EMFBalancer,
        ChakraAligner,
        Custom
    }

    /// @notice Certification tiers
    enum CertificationTier {
        Uncertified,
        Bronze,     // Basic safety certified
        Silver,     // Clinical grade
        Gold,       // Medical device approved
        Platinum    // Research grade
    }

    /// @notice Device certification structure (soulbound)
    struct DeviceCertification {
        bytes32 deviceHash;         // Hardware fingerprint hash
        DeviceType deviceType;
        CertificationTier tier;
        address manufacturer;
        uint256 certifiedAt;
        uint256 expiresAt;          // 0 = never
        bool isRevoked;
        bytes32 firmwareHash;       // Approved firmware version
    }

    /// @notice Biofeedback session record (hash-only)
    struct SessionRecord {
        bytes32 sessionHash;        // Hash of session data
        bytes32 deviceHash;         // Certified device used
        bytes32 userIdentity;       // Sovereign identity
        uint256 startTime;
        uint256 duration;
        bytes32 metricsHash;        // Compressed metrics hash
    }

    /// @notice Emitted when device is certified
    event DeviceCertified(
        bytes32 indexed deviceHash,
        DeviceType deviceType,
        CertificationTier tier,
        address indexed manufacturer,
        uint256 expiresAt
    );

    /// @notice Emitted when certification is revoked
    event CertificationRevoked(
        bytes32 indexed deviceHash,
        bytes32 reasonHash,
        uint256 timestamp
    );

    /// @notice Emitted when biofeedback session is recorded
    event SessionRecorded(
        bytes32 indexed sessionHash,
        bytes32 indexed deviceHash,
        bytes32 indexed userIdentity,
        uint256 timestamp
    );

    /// @notice Certify a new device (soulbound NFT)
    /// @param _deviceHash Hardware fingerprint
    /// @param _deviceType Type of device
    /// @param _tier Certification level
    /// @param _expiresAt Certification expiry (0 = never)
    /// @param _firmwareHash Approved firmware
    function certifyDevice(
        bytes32 _deviceHash,
        DeviceType _deviceType,
        CertificationTier _tier,
        uint256 _expiresAt,
        bytes32 _firmwareHash
    ) external returns (bool);

    /// @notice Revoke device certification
    /// @param _deviceHash Device to revoke
    /// @param _reasonHash Hash of revocation reason
    function revokeCertification(
        bytes32 _deviceHash,
        bytes32 _reasonHash
    ) external;

    /// @notice Record a biofeedback session
    /// @param _sessionHash Hash of session data
    /// @param _deviceHash Certified device used
    /// @param _userIdentity User's sovereign identity
    /// @param _duration Session length in seconds
    /// @param _metricsHash Compressed metrics
    function recordSession(
        bytes32 _sessionHash,
        bytes32 _deviceHash,
        bytes32 _userIdentity,
        uint256 _duration,
        bytes32 _metricsHash
    ) external returns (bool);

    /// @notice Check if device is certified and valid
    /// @param _deviceHash Device to check
    function isDeviceCertified(bytes32 _deviceHash) external view returns (bool);

    /// @notice Get device certification details
    /// @param _deviceHash Device identifier
    function getCertification(
        bytes32 _deviceHash
    ) external view returns (DeviceCertification memory);

    /// @notice Get user's session history (hash list)
    /// @param _userIdentity User's sovereign identity
    function getUserSessions(
        bytes32 _userIdentity
    ) external view returns (bytes32[] memory sessionHashes);
}
