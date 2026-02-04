// SPDX-License-Identifier: MIT
/**
 * @title SofieOSAdapter
 * @notice Bridge for SofieOS oracle and device integration
 * @dev Implements ISofieOracle for cross-system data feeds
 */
pragma solidity ^0.8.24;

import {ISofieOracle} from "../interfaces/ISofieOracle.sol";

contract SofieOSAdapter is ISofieOracle {
    
    // ============ Storage ============
    
    address public sovereignIdentity;
    address public accessGovernor;
    address public auditTrail;
    
    // Feed ID => feed data
    mapping(bytes32 => DataFeed) private dataFeeds;
    
    // Request ID => request data
    mapping(bytes32 => OracleRequest) private requests;
    
    // Authorized oracle providers
    mapping(address => bool) public oracleProviders;
    
    // Nonce for request ID generation
    uint256 private requestNonce;
    
    // ============ Modifiers ============
    
    modifier onlyOracleProvider() {
        require(oracleProviders[msg.sender], "SofieOSAdapter: Not oracle provider");
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
        oracleProviders[msg.sender] = true;
    }
    
    // ============ Admin Functions ============
    
    function addOracleProvider(address provider) external {
        require(
            msg.sender == accessGovernor || msg.sender == sovereignIdentity,
            "SofieOSAdapter: Not authorized"
        );
        oracleProviders[provider] = true;
    }
    
    function removeOracleProvider(address provider) external {
        require(
            msg.sender == accessGovernor || msg.sender == sovereignIdentity,
            "SofieOSAdapter: Not authorized"
        );
        oracleProviders[provider] = false;
    }
    
    // ============ ISofieOracle Implementation ============
    
    function registerDataFeed(
        bytes32 _feedId,
        DataType _dataType,
        uint256 _updateInterval
    ) external override onlyOracleProvider returns (bool) {
        require(_feedId != bytes32(0), "SofieOSAdapter: Invalid feed ID");
        require(dataFeeds[_feedId].feedId == bytes32(0), "SofieOSAdapter: Feed exists");
        
        DataFeed memory feed = DataFeed({
            feedId: _feedId,
            dataType: _dataType,
            oracleProvider: msg.sender,
            updateInterval: _updateInterval,
            lastUpdate: 0,
            latestDataHash: bytes32(0),
            isActive: true
        });
        
        dataFeeds[_feedId] = feed;
        
        emit DataFeedRegistered(_feedId, _dataType, msg.sender, _updateInterval);
        
        return true;
    }
    
    function updateDataFeed(
        bytes32 _feedId,
        bytes32 _dataHash,
        VerificationLevel _verification
    ) external override onlyOracleProvider returns (bool) {
        DataFeed storage feed = dataFeeds[_feedId];
        require(feed.feedId != bytes32(0), "SofieOSAdapter: Feed not found");
        require(feed.isActive, "SofieOSAdapter: Feed inactive");
        require(
            block.timestamp >= feed.lastUpdate + feed.updateInterval,
            "SofieOSAdapter: Update too soon"
        );
        
        feed.latestDataHash = _dataHash;
        feed.lastUpdate = block.timestamp;
        
        emit DataFeedUpdated(_feedId, _dataHash, block.timestamp, _verification);
        
        return true;
    }
    
    function requestOracleData(
        DataType _dataType,
        bytes32 _queryHash,
        uint256 _timeout
    ) external override returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked(msg.sender, block.timestamp, requestNonce++));
        
        OracleRequest memory request = OracleRequest({
            requestId: requestId,
            requester: msg.sender,
            dataType: _dataType,
            queryHash: _queryHash,
            requestedAt: block.timestamp,
            timeout: _timeout,
            isFulfilled: false,
            resultHash: bytes32(0)
        });
        
        requests[requestId] = request;
        
        emit OracleRequested(requestId, msg.sender, _dataType, _queryHash);
        
        return requestId;
    }
    
    function fulfillOracleRequest(
        bytes32 _requestId,
        bytes32 _resultHash,
        VerificationLevel _verification
    ) external override onlyOracleProvider returns (bool) {
        OracleRequest storage request = requests[_requestId];
        require(request.requestId != bytes32(0), "SofieOSAdapter: Request not found");
        require(!request.isFulfilled, "SofieOSAdapter: Already fulfilled");
        require(
            block.timestamp <= request.requestedAt + request.timeout,
            "SofieOSAdapter: Request timed out"
        );
        
        request.resultHash = _resultHash;
        request.isFulfilled = true;
        
        emit OracleFulfilled(_requestId, _resultHash, _verification);
        
        return true;
    }
    
    function getLatestData(
        bytes32 _feedId
    ) external view override returns (bytes32 dataHash, uint256 timestamp, VerificationLevel verification) {
        DataFeed storage feed = dataFeeds[_feedId];
        return (feed.latestDataHash, feed.lastUpdate, VerificationLevel.Signed);
    }
    
    function isFeedActive(bytes32 _feedId) external view override returns (bool) {
        return dataFeeds[_feedId].isActive;
    }
    
    function getRequestStatus(
        bytes32 _requestId
    ) external view override returns (bool isFulfilled, bytes32 resultHash) {
        OracleRequest storage request = requests[_requestId];
        return (request.isFulfilled, request.resultHash);
    }
    
    // ============ Additional Functions ============
    
    function deactivateFeed(bytes32 _feedId) external {
        require(
            msg.sender == accessGovernor || 
            msg.sender == sovereignIdentity ||
            msg.sender == dataFeeds[_feedId].oracleProvider,
            "SofieOSAdapter: Not authorized"
        );
        dataFeeds[_feedId].isActive = false;
    }
    
    function getFeedDetails(bytes32 _feedId) external view returns (DataFeed memory) {
        return dataFeeds[_feedId];
    }
    
    function getRequestDetails(bytes32 _requestId) external view returns (OracleRequest memory) {
        return requests[_requestId];
    }
}
