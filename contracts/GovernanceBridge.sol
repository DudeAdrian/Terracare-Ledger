// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TokenEngine.sol";
import "./IdentityRegistry.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title GovernanceBridge
 * @dev Manages transition from PoA validators to MINE-token-holder governance
 * - Month 18 timelock for transition
 * - Staking and proposal mechanisms
 * - Progressive decentralization
 */
contract GovernanceBridge is AccessControl, ReentrancyGuard {
    
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    TokenEngine public tokenEngine;
    IdentityRegistry public identityRegistry;
    
    // Governance phases
    enum GovernancePhase {
        PoA,              // Month 0-18: Proof of Authority (validators only)
        Transition,       // Month 18-24: Gradual transition
        Cooperative       // Month 24+: Full cooperative governance
    }
    
    GovernancePhase public currentPhase = GovernancePhase.PoA;
    uint256 public constant DEPLOYMENT_TIMESTAMP = 0; // Set in constructor
    uint256 public constant TRANSITION_START_MONTH = 18;
    uint256 public constant FULL_COOPERATIVE_MONTH = 24;
    uint256 public constant MONTH_IN_SECONDS = 30 days;
    
    // Proposal system
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        bytes callData;
        address target;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
    }
    
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18; // 1000 MINE staked
    uint256 public constant QUORUM_VOTES = 10000 * 10**18; // Minimum votes for validity
    
    // Timelock
    struct TimelockOperation {
        bytes32 id;
        address target;
        uint256 value;
        bytes data;
        bool executed;
        uint256 scheduledTime;
        uint256 delay;
    }
    
    mapping(bytes32 => TimelockOperation) public timelockOperations;
    uint256 public constant TIMELOCK_DELAY = 2 days;
    
    // Validator set (PoA phase)
    address[] public validators;
    mapping(address => bool) public isValidator;
    uint256 public requiredValidatorSignatures = 2; // Multi-sig requirement
    
    // Delegation
    mapping(address => address) public delegates;
    mapping(address => uint256) public delegatedVotes;
    
    // Events
    event PhaseTransition(GovernancePhase newPhase, uint256 timestamp);
    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        string title,
        uint256 startTime,
        uint256 endTime
    );
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        bool support,
        uint256 votes
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event OperationScheduled(bytes32 indexed operationId, uint256 scheduledTime);
    event OperationExecuted(bytes32 indexed operationId);
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    
    modifier onlyValidator() {
        require(isValidator[msg.sender], "Not a validator");
        _;
    }
    
    modifier onlyDuringPhase(GovernancePhase phase) {
        require(currentPhase == phase, "Wrong governance phase");
        _;
    }
    
    constructor(
        address _tokenEngine,
        address _identityRegistry,
        address[] memory initialValidators
    ) {
        require(_tokenEngine != address(0), "Invalid TokenEngine");
        require(_identityRegistry != address(0), "Invalid IdentityRegistry");
        require(initialValidators.length >= 2, "Need at least 2 validators");
        
        tokenEngine = TokenEngine(_tokenEngine);
        identityRegistry = IdentityRegistry(_identityRegistry);
        
        // Set initial validators
        for (uint i = 0; i < initialValidators.length; i++) {
            require(initialValidators[i] != address(0), "Invalid validator");
            validators.push(initialValidators[i]);
            isValidator[initialValidators[i]] = true;
            _grantRole(VALIDATOR_ROLE, initialValidators[i]);
        }
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PROPOSER_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
    }
    
    /**
     * @dev Check and update governance phase based on time
     */
    function updatePhase() public {
        uint256 monthsSinceDeployment = (block.timestamp - DEPLOYMENT_TIMESTAMP) / MONTH_IN_SECONDS;
        
        if (monthsSinceDeployment >= FULL_COOPERATIVE_MONTH && currentPhase != GovernancePhase.Cooperative) {
            currentPhase = GovernancePhase.Cooperative;
            emit PhaseTransition(GovernancePhase.Cooperative, block.timestamp);
        } else if (monthsSinceDeployment >= TRANSITION_START_MONTH && currentPhase == GovernancePhase.PoA) {
            currentPhase = GovernancePhase.Transition;
            emit PhaseTransition(GovernancePhase.Transition, block.timestamp);
        }
    }
    
    /**
     * @dev Create proposal (requires MINE stake)
     */
    function propose(
        string calldata title,
        string calldata description,
        address target,
        bytes calldata callData
    ) external returns (uint256) {
        updatePhase();
        
        uint256 proposerVotes = getVotes(msg.sender);
        
        if (currentPhase == GovernancePhase.PoA) {
            require(isValidator[msg.sender], "Only validators can propose in PoA");
        } else {
            require(proposerVotes >= PROPOSAL_THRESHOLD, "Insufficient voting power");
        }
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.callData = callData;
        newProposal.target = target;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_PERIOD;
        newProposal.executed = false;
        newProposal.canceled = false;
        
        emit ProposalCreated(proposalId, msg.sender, title, newProposal.startTime, newProposal.endTime);
        
        return proposalId;
    }
    
    /**
     * @dev Cast vote on proposal
     */
    function castVote(uint256 proposalId, bool support) external {
        updatePhase();
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(!proposal.canceled, "Proposal canceled");
        
        uint256 votes = getVotes(msg.sender);
        require(votes > 0, "No voting power");
        
        proposal.hasVoted[msg.sender] = true;
        
        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }
        
        emit VoteCast(msg.sender, proposalId, support, votes);
    }
    
    /**
     * @dev Execute proposal after voting period
     */
    function execute(uint256 proposalId) external nonReentrant {
        updatePhase();
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp > proposal.endTime, "Voting ongoing");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");
        require(
            proposal.forVotes > proposal.againstVotes && 
            (proposal.forVotes + proposal.againstVotes) >= QUORUM_VOTES,
            "Quorum not reached"
        );
        
        // Schedule in timelock
        bytes32 operationId = keccak256(abi.encode(
            proposal.target,
            0,
            proposal.callData,
            block.timestamp
        ));
        
        timelockOperations[operationId] = TimelockOperation({
            id: operationId,
            target: proposal.target,
            value: 0,
            data: proposal.callData,
            executed: false,
            scheduledTime: block.timestamp,
            delay: TIMELOCK_DELAY
        });
        
        proposal.executed = true;
        
        emit OperationScheduled(operationId, block.timestamp);
        emit ProposalExecuted(proposalId);
    }
    
    /**
     * @dev Execute timelocked operation
     */
    function executeTimelock(bytes32 operationId) external nonReentrant {
        TimelockOperation storage operation = timelockOperations[operationId];
        require(operation.id != bytes32(0), "Operation not found");
        require(!operation.executed, "Already executed");
        require(
            block.timestamp >= operation.scheduledTime + operation.delay,
            "Timelock not expired"
        );
        
        operation.executed = true;
        
        (bool success, ) = operation.target.call{value: operation.value}(operation.data);
        require(success, "Execution failed");
        
        emit OperationExecuted(operationId);
    }
    
    /**
     * @dev Cancel proposal (proposer or validators)
     */
    function cancel(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(
            msg.sender == proposal.proposer || isValidator[msg.sender],
            "Not authorized"
        );
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Already canceled");
        
        proposal.canceled = true;
        
        emit ProposalCanceled(proposalId);
    }
    
    /**
     * @dev Get voting power (staked MINE + delegated)
     */
    function getVotes(address account) public view returns (uint256) {
        uint256 directVotes = tokenEngine.getVotingPower(account);
        uint256 delegatedVote = delegatedVotes[account];
        return directVotes + delegatedVote;
    }
    
    /**
     * @dev Delegate voting power
     */
    function delegate(address delegatee) external {
        require(delegatee != address(0), "Cannot delegate to zero");
        require(delegatee != msg.sender, "Cannot delegate to self");
        
        address currentDelegate = delegates[msg.sender];
        uint256 senderBalance = tokenEngine.getTotalMINE(msg.sender);
        
        // Remove delegation from current
        if (currentDelegate != address(0)) {
            delegatedVotes[currentDelegate] -= senderBalance;
        }
        
        // Add to new delegatee
        delegates[msg.sender] = delegatee;
        delegatedVotes[delegatee] += senderBalance;
        
        emit DelegateChanged(msg.sender, currentDelegate, delegatee);
    }
    
    /**
     * @dev Remove delegation
     */
    function undelegate() external {
        address currentDelegate = delegates[msg.sender];
        require(currentDelegate != address(0), "Not delegating");
        
        uint256 senderBalance = tokenEngine.getTotalMINE(msg.sender);
        delegatedVotes[currentDelegate] -= senderBalance;
        delegates[msg.sender] = address(0);
        
        emit DelegateChanged(msg.sender, currentDelegate, address(0));
    }
    
    /**
     * @dev Add validator (PoA phase only)
     */
    function addValidator(address validator) external onlyRole(ADMIN_ROLE) {
        require(!isValidator[validator], "Already validator");
        validators.push(validator);
        isValidator[validator] = true;
        _grantRole(VALIDATOR_ROLE, validator);
        
        emit ValidatorAdded(validator);
    }
    
    /**
     * @dev Remove validator (PoA phase only)
     */
    function removeValidator(address validator) external onlyRole(ADMIN_ROLE) {
        require(isValidator[validator], "Not a validator");
        require(validators.length > requiredValidatorSignatures, "Cannot remove last validators");
        
        isValidator[validator] = false;
        _revokeRole(VALIDATOR_ROLE, validator);
        
        // Compact array
        for (uint i = 0; i < validators.length; i++) {
            if (validators[i] == validator) {
                validators[i] = validators[validators.length - 1];
                validators.pop();
                break;
            }
        }
        
        emit ValidatorRemoved(validator);
    }
    
    /**
     * @dev Get proposal state
     */
    function getProposalState(uint256 proposalId) external view returns (string memory) {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.canceled) return "Canceled";
        if (proposal.executed) return "Executed";
        if (block.timestamp <= proposal.startTime) return "Pending";
        if (block.timestamp <= proposal.endTime) return "Active";
        if (proposal.forVotes <= proposal.againstVotes || 
            (proposal.forVotes + proposal.againstVotes) < QUORUM_VOTES) return "Defeated";
        return "Succeeded";
    }
    
    /**
     * @dev Get all validators
     */
    function getValidators() external view returns (address[] memory) {
        return validators;
    }
    
    /**
     * @dev Check if can propose
     */
    function canPropose(address account) external view returns (bool) {
        if (currentPhase == GovernancePhase.PoA) {
            return isValidator[account];
        }
        return getVotes(account) >= PROPOSAL_THRESHOLD;
    }
    
    /**
     * @dev Get current phase as string
     */
    function getCurrentPhase() external view returns (string memory) {
        if (currentPhase == GovernancePhase.PoA) return "PoA";
        if (currentPhase == GovernancePhase.Transition) return "Transition";
        return "Cooperative";
    }
    
    /**
     * @dev Get time until next phase
     */
    function getTimeUntilNextPhase() external view returns (uint256) {
        uint256 monthsSinceDeployment = (block.timestamp - DEPLOYMENT_TIMESTAMP) / MONTH_IN_SECONDS;
        
        if (currentPhase == GovernancePhase.PoA) {
            uint256 transitionTime = DEPLOYMENT_TIMESTAMP + (TRANSITION_START_MONTH * MONTH_IN_SECONDS);
            if (block.timestamp >= transitionTime) return 0;
            return transitionTime - block.timestamp;
        }
        
        if (currentPhase == GovernancePhase.Transition) {
            uint256 cooperativeTime = DEPLOYMENT_TIMESTAMP + (FULL_COOPERATIVE_MONTH * MONTH_IN_SECONDS);
            if (block.timestamp >= cooperativeTime) return 0;
            return cooperativeTime - block.timestamp;
        }
        
        return 0; // Already at Cooperative
    }
}
