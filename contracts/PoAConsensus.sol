// SPDX-License-Identifier: MIT
// Pillar-1: PoA validator consensus for sandironratio-node
// Pillar-2: First Principles: Health data requires trusted validators
// Pillar-3: Genius Channeled - Satoshi (distributed consensus)
// Pillar-4: Validator network as strategic asset
// Pillar-5: Red Team Architecture - rotate validators regularly
// Pillar-6: OODA Loops for validator health monitoring
// Pillar-7: Build for 100-year network longevity

pragma solidity ^0.8.24;

import "./SovereignIdentity.sol";
import "./AuditTrail.sol";

/**
 * @title PoAConsensus
 * @dev Proof of Authority consensus interface for sandironratio-node
 *      - Validator registration and rotation
 *      - Health-check endpoints for OODA loop monitoring
 *      - Block finalization tracking
 *      - Validator reputation scoring
 */
contract PoAConsensus {
    // ============ Structs ============
    
    struct Validator {
        address validatorAddress;
        bytes32 nodeId;             // sandironratio-node identifier
        uint256 registeredAt;
        uint256 lastSeen;
        bool active;
        uint256 blocksProposed;
        uint256 blocksFinalized;
        uint256 reputationScore;    // 0-10000
        bytes32 endpointHash;       // Hash of validator endpoint
        uint256 stakeAmount;        // Optional stake for slashing
    }

    struct BlockFinalization {
        uint256 blockNumber;
        bytes32 blockHash;
        address proposer;
        address[] validators;
        uint256 finalizedAt;
        bytes32 stateRoot;
    }

    struct HealthCheck {
        address validator;
        uint256 timestamp;
        bytes32 statusHash;         // Hash of detailed status
        bool healthy;
        uint256 latency;            // ms
        uint256 peerCount;
    }

    // ============ State ============
    
    SovereignIdentity public identity;
    AuditTrail public auditTrail;
    
    address public governance;
    
    // Validator address => Validator
    mapping(address => Validator) public validators;
    address[] public validatorList;
    
    // Block number => BlockFinalization
    mapping(uint256 => BlockFinalization) public finalizations;
    
    // Validator => health checks (circular buffer)
    mapping(address => HealthCheck[]) public healthChecks;
    mapping(address => uint256) public healthCheckIndex;
    
    // Minimum validators for consensus
    uint256 public minValidators = 3;
    
    // Required reputation for validation
    uint256 public minReputation = 5000; // 50%
    
    // Health check timeout
    uint256 public healthCheckTimeout = 300; // 5 minutes
    
    // Active validator count
    uint256 public activeValidatorCount;

    // ============ Events ============
    
    event ValidatorRegistered(
        address indexed validator,
        bytes32 nodeId,
        uint256 stakeAmount
    );
    
    event ValidatorActivated(address indexed validator);
    event ValidatorDeactivated(address indexed validator, bytes32 reasonHash);
    event BlockFinalized(
        uint256 indexed blockNumber,
        bytes32 indexed blockHash,
        address indexed proposer
    );
    
    event HealthCheckSubmitted(
        address indexed validator,
        bool healthy,
        uint256 latency
    );
    
    event ReputationUpdated(
        address indexed validator,
        uint256 newScore
    );

    // ============ Modifiers ============
    
    modifier onlyGovernance() {
        require(msg.sender == governance, "PoAConsensus: Not governance");
        _;
    }

    modifier onlyValidator() {
        require(validators[msg.sender].active, "PoAConsensus: Not active validator");
        _;
    }

    modifier sufficientValidators() {
        require(activeValidatorCount >= minValidators, "PoAConsensus: Insufficient validators");
        _;
    }

    // ============ Constructor ============
    
    constructor(address _identity, address _auditTrail) {
        identity = SovereignIdentity(_identity);
        auditTrail = AuditTrail(_auditTrail);
        governance = msg.sender;
    }

    // ============ Validator Management ============
    
    /**
     * @dev Register new sandironratio-node validator
     */
    function registerValidator(
        address validatorAddress,
        bytes32 nodeId,
        bytes32 endpointHash
    ) external payable onlyGovernance {
        require(validators[validatorAddress].registeredAt == 0, "PoAConsensus: Already registered");

        validators[validatorAddress] = Validator({
            validatorAddress: validatorAddress,
            nodeId: nodeId,
            registeredAt: block.timestamp,
            lastSeen: block.timestamp,
            active: true,
            blocksProposed: 0,
            blocksFinalized: 0,
            reputationScore: 5000, // Start at 50%
            endpointHash: endpointHash,
            stakeAmount: msg.value
        });

        validatorList.push(validatorAddress);
        activeValidatorCount++;

        auditTrail.createEntry(
            address(0),
            SovereignIdentity.SystemType.SandIronNode,
            keccak256("VALIDATOR_REGISTERED"),
            nodeId,
            new bytes32[](0)
        );

        emit ValidatorRegistered(validatorAddress, nodeId, msg.value);
    }

    /**
     * @dev Activate validator
     */
    function activateValidator(address validator) external onlyGovernance {
        require(validators[validator].registeredAt != 0, "PoAConsensus: Not registered");
        require(!validators[validator].active, "PoAConsensus: Already active");
        
        validators[validator].active = true;
        activeValidatorCount++;

        emit ValidatorActivated(validator);
    }

    /**
     * @dev Deactivate validator (rotate out)
     * Pillar-5: Red Team Architecture - regular rotation
     */
    function deactivateValidator(address validator, bytes32 reasonHash) external onlyGovernance {
        require(validators[validator].active, "PoAConsensus: Not active");
        
        validators[validator].active = false;
        activeValidatorCount--;

        auditTrail.createEntry(
            address(0),
            SovereignIdentity.SystemType.SandIronNode,
            keccak256("VALIDATOR_DEACTIVATED"),
            reasonHash,
            new bytes32[](0)
        );

        emit ValidatorDeactivated(validator, reasonHash);
    }

    /**
     * @dev Slash validator for misbehavior
     */
    function slashValidator(address validator, uint256 amount, bytes32 reasonHash) external onlyGovernance {
        Validator storage v = validators[validator];
        require(v.registeredAt != 0, "PoAConsensus: Not registered");
        
        uint256 slashAmount = amount > v.stakeAmount ? v.stakeAmount : amount;
        v.stakeAmount -= slashAmount;
        v.reputationScore = v.reputationScore > 1000 ? v.reputationScore - 1000 : 0;

        // Transfer slashed amount to governance
        payable(governance).transfer(slashAmount);

        auditTrail.createEntry(
            address(0),
            SovereignIdentity.SystemType.SandIronNode,
            keccak256("VALIDATOR_SLASHED"),
            reasonHash,
            new bytes32[](0)
        );
    }

    // ============ Block Finalization ============
    
    /**
     * @dev Record block finalization
     */
    function finalizeBlock(
        uint256 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot,
        address[] calldata signingValidators
    ) external onlyValidator sufficientValidators {
        require(finalizations[blockNumber].blockHash == bytes32(0), "PoAConsensus: Already finalized");
        require(signingValidators.length >= minValidators, "PoAConsensus: Insufficient signatures");

        // Verify all signers are active validators
        for (uint i = 0; i < signingValidators.length; i++) {
            require(validators[signingValidators[i]].active, "PoAConsensus: Inactive signer");
        }

        finalizations[blockNumber] = BlockFinalization({
            blockNumber: blockNumber,
            blockHash: blockHash,
            proposer: msg.sender,
            validators: signingValidators,
            finalizedAt: block.timestamp,
            stateRoot: stateRoot
        });

        // Update validator stats
        validators[msg.sender].blocksProposed++;
        for (uint i = 0; i < signingValidators.length; i++) {
            validators[signingValidators[i]].blocksFinalized++;
        }

        auditTrail.createEntry(
            address(0),
            SovereignIdentity.SystemType.SandIronNode,
            keccak256("BLOCK_FINALIZED"),
            blockHash,
            new bytes32[](0)
        );

        emit BlockFinalized(blockNumber, blockHash, msg.sender);
    }

    // ============ Health Check (OODA Loop) ============
    
    /**
     * @dev Submit health check - OODA Loop Phase 1: Observe
     * Pillar-6: OODA Loops for validator health monitoring
     */
    function submitHealthCheck(
        bytes32 statusHash,
        bool healthy,
        uint256 latency,
        uint256 peerCount
    ) external onlyValidator {
        HealthCheck memory check = HealthCheck({
            validator: msg.sender,
            timestamp: block.timestamp,
            statusHash: statusHash,
            healthy: healthy,
            latency: latency,
            peerCount: peerCount
        });

        // Store in circular buffer (keep last 100)
        if (healthChecks[msg.sender].length < 100) {
            healthChecks[msg.sender].push(check);
        } else {
            uint256 index = healthCheckIndex[msg.sender];
            healthChecks[msg.sender][index] = check;
            healthCheckIndex[msg.sender] = (index + 1) % 100;
        }

        validators[msg.sender].lastSeen = block.timestamp;

        // Update reputation based on health
        if (healthy && latency < 1000) {
            _increaseReputation(msg.sender, 10);
        } else {
            _decreaseReputation(msg.sender, 50);
        }

        emit HealthCheckSubmitted(msg.sender, healthy, latency);
    }

    /**
     * @dev Check if validator is healthy
     */
    function isValidatorHealthy(address validator) external view returns (bool) {
        Validator memory v = validators[validator];
        if (!v.active) return false;
        if (block.timestamp - v.lastSeen > healthCheckTimeout) return false;
        if (v.reputationScore < minReputation) return false;
        return true;
    }

    // ============ Reputation Management ============
    
    function _increaseReputation(address validator, uint256 amount) internal {
        Validator storage v = validators[validator];
        v.reputationScore = v.reputationScore + amount > 10000 ? 10000 : v.reputationScore + amount;
        emit ReputationUpdated(validator, v.reputationScore);
    }

    function _decreaseReputation(address validator, uint256 amount) internal {
        Validator storage v = validators[validator];
        v.reputationScore = v.reputationScore > amount ? v.reputationScore - amount : 0;
        emit ReputationUpdated(validator, v.reputationScore);
    }

    /**
     * @dev Manual reputation adjustment (governance)
     */
    function adjustReputation(address validator, uint256 newScore) external onlyGovernance {
        require(newScore <= 10000, "PoAConsensus: Score too high");
        validators[validator].reputationScore = newScore;
        emit ReputationUpdated(validator, newScore);
    }

    // ============ Configuration ============
    
    function setMinValidators(uint256 count) external onlyGovernance {
        minValidators = count;
    }

    function setMinReputation(uint256 score) external onlyGovernance {
        minReputation = score;
    }

    function setHealthCheckTimeout(uint256 timeout) external onlyGovernance {
        healthCheckTimeout = timeout;
    }

    // ============ View Functions ============
    
    function getValidator(address validator) external view returns (Validator memory) {
        return validators[validator];
    }

    function getFinalization(uint256 blockNumber) external view returns (BlockFinalization memory) {
        return finalizations[blockNumber];
    }

    function getValidatorHealthChecks(address validator) external view returns (HealthCheck[] memory) {
        return healthChecks[validator];
    }

    function getValidatorList() external view returns (address[] memory) {
        return validatorList;
    }

    function getActiveValidators() external view returns (address[] memory) {
        address[] memory active = new address[](activeValidatorCount);
        uint256 index = 0;
        for (uint i = 0; i < validatorList.length; i++) {
            if (validators[validatorList[i]].active) {
                active[index] = validatorList[i];
                index++;
            }
        }
        return active;
    }

    /**
     * @dev Get consensus health metrics
     */
    function getConsensusHealth() external view returns (
        uint256 activeValidators,
        uint256 totalValidators,
        uint256 avgReputation,
        uint256 healthCheckPassRate
    ) {
        activeValidators = activeValidatorCount;
        totalValidators = validatorList.length;
        
        uint256 totalReputation = 0;
        uint256 healthyChecks = 0;
        uint256 totalChecks = 0;

        for (uint i = 0; i < validatorList.length; i++) {
            Validator memory v = validators[validatorList[i]];
            totalReputation += v.reputationScore;
            
            HealthCheck[] memory checks = healthChecks[validatorList[i]];
            for (uint j = 0; j < checks.length; j++) {
                totalChecks++;
                if (checks[j].healthy) healthyChecks++;
            }
        }

        avgReputation = totalValidators > 0 ? totalReputation / totalValidators : 0;
        healthCheckPassRate = totalChecks > 0 ? (healthyChecks * 10000) / totalChecks : 0;

        return (activeValidators, totalValidators, avgReputation, healthCheckPassRate);
    }

    // Allow contract to receive ETH for staking
    receive() external payable {}
}
