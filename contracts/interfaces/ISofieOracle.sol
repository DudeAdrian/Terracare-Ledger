// SPDX-License-Identifier: MIT
/**
 * @title ISofieOracle
 * @notice Interface for SofieOS oracle services
 * @dev Cross-system data oracle and verification layer
 */
pragma solidity ^0.8.24;

interface ISofieOracle {
    /// @notice Oracle data types
    enum DataType {
        DeviceTelemetry,
        UserPreference,
        SystemStatus,
        ExternalAPI,
        WeatherData,
        LocationData,
        BiometricData,
        MarketData,
        Custom
    }

    /// @notice Data verification levels
    enum VerificationLevel {
        Unverified,
        Signed,         // Cryptographically signed
        MultiSigned,    // Multiple oracle signatures
        Consensus,      // Network consensus
        Hardware        // Hardware attestation
    }

    /// @notice Oracle data feed
    struct DataFeed {
        bytes32 feedId;
        DataType dataType;
        address oracleProvider;
        uint256 updateInterval;
        uint256 lastUpdate;
        bytes32 latestDataHash;
        bool isActive;
    }

    /// @notice Oracle request
    struct OracleRequest {
        bytes32 requestId;
        address requester;
        DataType dataType;
        bytes32 queryHash;
        uint256 requestedAt;
        uint256 timeout;
        bool isFulfilled;
        bytes32 resultHash;
    }

    /// @notice Emitted when data feed is registered
    event DataFeedRegistered(
        bytes32 indexed feedId,
        DataType dataType,
        address indexed oracleProvider,
        uint256 updateInterval
    );

    /// @notice Emitted when data feed is updated
    event DataFeedUpdated(
        bytes32 indexed feedId,
        bytes32 newDataHash,
        uint256 timestamp,
        VerificationLevel verification
    );

    /// @notice Emitted when oracle request is made
    event OracleRequested(
        bytes32 indexed requestId,
        address indexed requester,
        DataType dataType,
        bytes32 queryHash
    );

    /// @notice Emitted when oracle request is fulfilled
    event OracleFulfilled(
        bytes32 indexed requestId,
        bytes32 resultHash,
        VerificationLevel verification
    );

    /// @notice Register a new data feed
    /// @param _feedId Unique feed identifier
    /// @param _dataType Type of data
    /// @param _updateInterval Minimum update interval
    function registerDataFeed(
        bytes32 _feedId,
        DataType _dataType,
        uint256 _updateInterval
    ) external returns (bool);

    /// @notice Update data feed value
    /// @param _feedId Feed to update
    /// @param _dataHash Hash of new data
    /// @param _verification Verification level achieved
    function updateDataFeed(
        bytes32 _feedId,
        bytes32 _dataHash,
        VerificationLevel _verification
    ) external returns (bool);

    /// @notice Request oracle data
    /// @param _dataType Type of data needed
    /// @param _queryHash Hash of query parameters
    /// @param _timeout Request timeout
    function requestOracleData(
        DataType _dataType,
        bytes32 _queryHash,
        uint256 _timeout
    ) external returns (bytes32 requestId);

    /// @notice Fulfill oracle request
    /// @param _requestId Request to fulfill
    /// @param _resultHash Hash of result data
    /// @param _verification Verification level
    function fulfillOracleRequest(
        bytes32 _requestId,
        bytes32 _resultHash,
        VerificationLevel _verification
    ) external returns (bool);

    /// @notice Get latest data feed value
    /// @param _feedId Feed identifier
    function getLatestData(
        bytes32 _feedId
    ) external view returns (bytes32 dataHash, uint256 timestamp, VerificationLevel verification);

    /// @notice Check if data feed is active
    /// @param _feedId Feed to check
    function isFeedActive(bytes32 _feedId) external view returns (bool);

    /// @notice Get request status
    /// @param _requestId Request identifier
    function getRequestStatus(
        bytes32 _requestId
    ) external view returns (bool isFulfilled, bytes32 resultHash);
}
