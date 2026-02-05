// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title AuditLog
 * @dev Append-only event emitter for access and data operations
 * v2.0: Added token mint/burn event logging for the participation layer
 */
contract AuditLog {
    
    // Original events
    event AccessEvent(address indexed actor, address indexed subject, string action, uint256 timestamp, bytes32 refHash);
    event DataEvent(address indexed actor, string action, uint256 timestamp, bytes32 dataHash, uint256 version);
    
    // Token events for v2.0
    event TokenMintEvent(
        address indexed actor,
        address indexed beneficiary,
        string tokenType,      // "MINE" or "WELL"
        uint256 amount,
        string source,         // "activity", "conversion", "purchase"
        uint256 valuePoints,   // For MINE: activity value points
        uint256 timestamp
    );
    
    event TokenBurnEvent(
        address indexed actor,
        address indexed from,
        string tokenType,      // "MINE" or "WELL"
        uint256 amount,
        string reason,         // "conversion", "purchase", "penalty"
        uint256 timestamp
    );
    
    event TokenTransferEvent(
        address indexed from,
        address indexed to,
        string tokenType,
        uint256 amount,
        uint256 timestamp
    );
    
    event StakeEvent(
        address indexed user,
        string action,         // "stake" or "unstake"
        uint256 amount,
        uint256 lockEnd,
        uint256 timestamp
    );
    
    event GovernanceEvent(
        address indexed actor,
        string action,
        uint256 proposalId,
        bytes32 data,
        uint256 timestamp
    );
    
    event RevenueEvent(
        address indexed source,
        uint256 amount,
        string revenueType,    // "stripe", "ndis", "direct"
        uint256 splitUser,
        uint256 splitInvestor,
        uint256 splitOperations,
        uint256 splitReserve,
        uint256 timestamp
    );
    
    event SecurityEvent(
        address indexed actor,
        string eventType,      // "rate_limit", "sybil_detected", "emergency"
        bytes32 target,
        string details,
        uint256 timestamp
    );

    // Access logging
    function logAccess(address subject, string calldata action, bytes32 refHash) external {
        emit AccessEvent(msg.sender, subject, action, block.timestamp, refHash);
    }

    function logData(string calldata action, bytes32 dataHash, uint256 version) external {
        emit DataEvent(msg.sender, action, block.timestamp, dataHash, version);
    }
    
    // Token logging functions
    function logTokenMint(
        address beneficiary,
        string calldata tokenType,
        uint256 amount,
        string calldata source,
        uint256 valuePoints
    ) external {
        emit TokenMintEvent(
            msg.sender,
            beneficiary,
            tokenType,
            amount,
            source,
            valuePoints,
            block.timestamp
        );
    }
    
    function logTokenBurn(
        address from,
        string calldata tokenType,
        uint256 amount,
        string calldata reason
    ) external {
        emit TokenBurnEvent(
            msg.sender,
            from,
            tokenType,
            amount,
            reason,
            block.timestamp
        );
    }
    
    function logTokenTransfer(
        address from,
        address to,
        string calldata tokenType,
        uint256 amount
    ) external {
        emit TokenTransferEvent(from, to, tokenType, amount, block.timestamp);
    }
    
    function logStake(
        address user,
        string calldata action,
        uint256 amount,
        uint256 lockEnd
    ) external {
        emit StakeEvent(user, action, amount, lockEnd, block.timestamp);
    }
    
    function logGovernance(
        string calldata action,
        uint256 proposalId,
        bytes32 data
    ) external {
        emit GovernanceEvent(msg.sender, action, proposalId, data, block.timestamp);
    }
    
    function logRevenue(
        uint256 amount,
        string calldata revenueType,
        uint256 splitUser,
        uint256 splitInvestor,
        uint256 splitOperations,
        uint256 splitReserve
    ) external {
        emit RevenueEvent(
            msg.sender,
            amount,
            revenueType,
            splitUser,
            splitInvestor,
            splitOperations,
            splitReserve,
            block.timestamp
        );
    }
    
    function logSecurity(
        string calldata eventType,
        bytes32 target,
        string calldata details
    ) external {
        emit SecurityEvent(
            msg.sender,
            eventType,
            target,
            details,
            block.timestamp
        );
    }
    
    // Batch logging for gas efficiency
    function batchLogAccess(
        address[] calldata subjects,
        string[] calldata actions,
        bytes32[] calldata refHashes
    ) external {
        require(
            subjects.length == actions.length && 
            subjects.length == refHashes.length,
            "Length mismatch"
        );
        
        for (uint i = 0; i < subjects.length; i++) {
            emit AccessEvent(msg.sender, subjects[i], actions[i], block.timestamp, refHashes[i]);
        }
    }
    
    function batchLogData(
        string[] calldata actions,
        bytes32[] calldata dataHashes,
        uint256[] calldata versions
    ) external {
        require(
            actions.length == dataHashes.length && 
            actions.length == versions.length,
            "Length mismatch"
        );
        
        for (uint i = 0; i < actions.length; i++) {
            emit DataEvent(msg.sender, actions[i], block.timestamp, dataHashes[i], versions[i]);
        }
    }
    
    // Query helpers (off-chain indexing hints)
    function getLogTopics() external pure returns (bytes32[] memory) {
        bytes32[] memory topics = new bytes32[](10);
        topics[0] = AccessEvent.selector;
        topics[1] = DataEvent.selector;
        topics[2] = TokenMintEvent.selector;
        topics[3] = TokenBurnEvent.selector;
        topics[4] = TokenTransferEvent.selector;
        topics[5] = StakeEvent.selector;
        topics[6] = GovernanceEvent.selector;
        topics[7] = RevenueEvent.selector;
        topics[8] = SecurityEvent.selector;
        return topics;
    }
}
