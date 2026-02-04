// SPDX-License-Identifier: MIT
/**
 * @title PoAConsensus
 * @notice Proof of Authority consensus for Terracare Ledger
 * @dev Validator management and block confirmation for private network
 */
pragma solidity ^0.8.24;

contract PoAConsensus {
    
    // ============ Types ============
    
    enum ValidatorStatus {
        Inactive,
        Active,
        Suspended,
        Revoked
    }
    
    struct Validator {
        address validatorAddress;
        bytes32 identityHash;       // Sovereign identity binding
        string name;                // Organization name
        string endpoint;            // Network endpoint (hash)
        uint256 stakedAmount;       // Stake for slashing
        uint256 registeredAt;
        uint256 lastBlockConfirmed;
        uint256 blocksConfirmed;
        ValidatorStatus status;
        uint256 reputation;         // Performance score (0-10000)
    }
    
    struct BlockConfirmation {
        bytes32 blockHash;
        uint256 blockNumber;
        address[] confirmingValidators;
        bytes32[] signatures;       // Hashes of signatures
        uint256 confirmedAt;
        bool isFinalized;
    }
    
    struct Proposal {
        bytes32 proposalHash;
        address proposer;
        bytes32 dataHash;           // Proposal data
        uint256 proposedAt;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        mapping(address => bool) hasVoted;
    }
    
    // ============ Storage ============
    
    address public sovereignIdentity;
    address public auditTrail;
    
    // Minimum validators required for consensus
    uint256 public constant MIN_VALIDATORS = 3;
    // Required confirmations for finality (2/3 majority)
    uint256 public constant CONFIRMATION_THRESHOLD_NUM = 2;
    uint256 public constant CONFIRMATION_THRESHOLD_DENOM = 3;
    
    // Validators
    mapping(address => Validator) public validators;
    address[] public validatorList;
    
    // Block confirmations
    mapping(bytes32 => BlockConfirmation) public confirmations;
    mapping(uint256 => bytes32) public blockHashByNumber;
    
    // Proposals
    mapping(bytes32 => Proposal) public proposals;
    
    // Admin
    address public admin;
    mapping(address => bool) public isAdmin;
    
    // ============ Events ============
    
    event ValidatorRegistered(
        address indexed validatorAddress,
        bytes32 indexed identityHash,
        string name,
        uint256 stakedAmount
    );
    
    event ValidatorActivated(address indexed validatorAddress);
    event ValidatorSuspended(address indexed validatorAddress, bytes32 reasonHash);
    event ValidatorRevoked(address indexed validatorAddress);
    
    event BlockConfirmed(
        bytes32 indexed blockHash,
        uint256 indexed blockNumber,
        address indexed validator,
        uint256 confirmationCount
    );
    
    event BlockFinalized(
        bytes32 indexed blockHash,
        uint256 indexed blockNumber,
        uint256 finalizedAt
    );
    
    event ProposalCreated(
        bytes32 indexed proposalHash,
        address indexed proposer,
        bytes32 dataHash
    );
    
    event ProposalVoted(
        bytes32 indexed proposalHash,
        address indexed voter,
        bool vote // true = for, false = against
    );
    
    event ProposalExecuted(bytes32 indexed proposalHash);
    
    // ============ Modifiers ============
    
    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "PoAConsensus: Not admin");
        _;
    }
    
    modifier onlyValidator() {
        require(validators[msg.sender].status == ValidatorStatus.Active, "PoAConsensus: Not active validator");
        _;
    }
    
    modifier onlySovereignIdentity() {
        require(msg.sender == sovereignIdentity, "PoAConsensus: Not sovereign identity");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address _sovereignIdentity, address _auditTrail) {
        sovereignIdentity = _sovereignIdentity;
        auditTrail = _auditTrail;
        admin = msg.sender;
        isAdmin[msg.sender] = true;
    }
    
    // ============ Admin Functions ============
    
    function addAdmin(address _admin) external {
        require(msg.sender == admin, "PoAConsensus: Not primary admin");
        isAdmin[_admin] = true;
    }
    
    function removeAdmin(address _admin) external {
        require(msg.sender == admin, "PoAConsensus: Not primary admin");
        require(_admin != admin, "PoAConsensus: Cannot remove primary admin");
        isAdmin[_admin] = false;
    }
    
    // ============ Validator Management ============
    
    function registerValidator(
        address _validatorAddress,
        bytes32 _identityHash,
        string calldata _name,
        string calldata _endpoint
    ) external payable onlyAdmin returns (bool) {
        require(_validatorAddress != address(0), "PoAConsensus: Invalid address");
        require(validators[_validatorAddress].validatorAddress == address(0), "PoAConsensus: Already registered");
        require(msg.value >= 1 ether, "PoAConsensus: Minimum 1 ETH stake required");
        
        Validator memory validator = Validator({
            validatorAddress: _validatorAddress,
            identityHash: _identityHash,
            name: _name,
            endpoint: _endpoint,
            stakedAmount: msg.value,
            registeredAt: block.timestamp,
            lastBlockConfirmed: 0,
            blocksConfirmed: 0,
            status: ValidatorStatus.Active,
            reputation: 5000 // Start with neutral reputation
        });
        
        validators[_validatorAddress] = validator;
        validatorList.push(_validatorAddress);
        
        emit ValidatorRegistered(_validatorAddress, _identityHash, _name, msg.value);
        
        return true;
    }
    
    function activateValidator(address _validatorAddress) external onlyAdmin {
        Validator storage validator = validators[_validatorAddress];
        require(validator.validatorAddress != address(0), "PoAConsensus: Not registered");
        validator.status = ValidatorStatus.Active;
        emit ValidatorActivated(_validatorAddress);
    }
    
    function suspendValidator(address _validatorAddress, bytes32 _reasonHash) external onlyAdmin {
        Validator storage validator = validators[_validatorAddress];
        require(validator.validatorAddress != address(0), "PoAConsensus: Not registered");
        validator.status = ValidatorStatus.Suspended;
        emit ValidatorSuspended(_validatorAddress, _reasonHash);
    }
    
    function revokeValidator(address _validatorAddress) external onlyAdmin {
        Validator storage validator = validators[_validatorAddress];
        require(validator.validatorAddress != address(0), "PoAConsensus: Not registered");
        validator.status = ValidatorStatus.Revoked;
        
        // Return stake
        payable(_validatorAddress).transfer(validator.stakedAmount);
        validator.stakedAmount = 0;
        
        emit ValidatorRevoked(_validatorAddress);
    }
    
    // ============ Block Confirmation ============
    
    function confirmBlock(
        bytes32 _blockHash,
        uint256 _blockNumber,
        bytes32 _signatureHash
    ) external onlyValidator returns (bool) {
        require(_blockHash != bytes32(0), "PoAConsensus: Invalid block hash");
        
        BlockConfirmation storage confirmation = confirmations[_blockHash];
        
        // Initialize new confirmation
        if (confirmation.blockHash == bytes32(0)) {
            confirmation.blockHash = _blockHash;
            confirmation.blockNumber = _blockNumber;
            confirmation.confirmedAt = 0; // Will be set when finalized
            confirmation.isFinalized = false;
            blockHashByNumber[_blockNumber] = _blockHash;
        }
        
        // Check validator hasn't already confirmed
        for (uint i = 0; i < confirmation.confirmingValidators.length; i++) {
            require(confirmation.confirmingValidators[i] != msg.sender, "PoAConsensus: Already confirmed");
        }
        
        confirmation.confirmingValidators.push(msg.sender);
        confirmation.signatures.push(_signatureHash);
        
        // Update validator stats
        Validator storage validator = validators[msg.sender];
        validator.lastBlockConfirmed = block.number;
        validator.blocksConfirmed++;
        
        emit BlockConfirmed(_blockHash, _blockNumber, msg.sender, confirmation.confirmingValidators.length);
        
        // Check if we have enough confirmations for finality
        uint256 threshold = (validatorList.length * CONFIRMATION_THRESHOLD_NUM) / CONFIRMATION_THRESHOLD_DENOM;
        if (confirmation.confirmingValidators.length >= threshold && !confirmation.isFinalized) {
            confirmation.isFinalized = true;
            confirmation.confirmedAt = block.timestamp;
            emit BlockFinalized(_blockHash, _blockNumber, block.timestamp);
        }
        
        return true;
    }
    
    // ============ Proposal System ============
    
    function createProposal(
        bytes32 _proposalHash,
        bytes32 _dataHash
    ) external onlyValidator returns (bool) {
        require(_proposalHash != bytes32(0), "PoAConsensus: Invalid proposal hash");
        require(proposals[_proposalHash].proposalHash == bytes32(0), "PoAConsensus: Proposal exists");
        
        Proposal storage proposal = proposals[_proposalHash];
        proposal.proposalHash = _proposalHash;
        proposal.proposer = msg.sender;
        proposal.dataHash = _dataHash;
        proposal.proposedAt = block.timestamp;
        proposal.votesFor = 0;
        proposal.votesAgainst = 0;
        proposal.executed = false;
        
        emit ProposalCreated(_proposalHash, msg.sender, _dataHash);
        
        return true;
    }
    
    function voteOnProposal(bytes32 _proposalHash, bool _vote) external onlyValidator {
        Proposal storage proposal = proposals[_proposalHash];
        require(proposal.proposalHash != bytes32(0), "PoAConsensus: Proposal not found");
        require(!proposal.executed, "PoAConsensus: Already executed");
        require(!proposal.hasVoted[msg.sender], "PoAConsensus: Already voted");
        
        proposal.hasVoted[msg.sender] = true;
        
        if (_vote) {
            proposal.votesFor++;
        } else {
            proposal.votesAgainst++;
        }
        
        emit ProposalVoted(_proposalHash, msg.sender, _vote);
        
        // Auto-execute if threshold reached
        uint256 threshold = (validatorList.length * CONFIRMATION_THRESHOLD_NUM) / CONFIRMATION_THRESHOLD_DENOM;
        if (proposal.votesFor >= threshold) {
            proposal.executed = true;
            emit ProposalExecuted(_proposalHash);
        }
    }
    
    // ============ Slashing ============
    
    function slashValidator(
        address _validatorAddress,
        uint256 _amount,
        bytes32 _reasonHash
    ) external onlyAdmin {
        Validator storage validator = validators[_validatorAddress];
        require(validator.validatorAddress != address(0), "PoAConsensus: Not registered");
        require(_amount <= validator.stakedAmount, "PoAConsensus: Insufficient stake");
        
        validator.stakedAmount -= _amount;
        validator.reputation = validator.reputation > 1000 ? validator.reputation - 1000 : 0;
        
        // Transfer slashed amount to admin (or burn)
        // In production, this might go to a treasury or be burned
    }
    
    // ============ View Functions ============
    
    function getValidator(address _validatorAddress) external view returns (Validator memory) {
        return validators[_validatorAddress];
    }
    
    function getValidatorCount() external view returns (uint256) {
        return validatorList.length;
    }
    
    function getActiveValidatorCount() external view returns (uint256 count) {
        for (uint i = 0; i < validatorList.length; i++) {
            if (validators[validatorList[i]].status == ValidatorStatus.Active) {
                count++;
            }
        }
    }
    
    function getBlockConfirmation(bytes32 _blockHash) external view returns (BlockConfirmation memory) {
        return confirmations[_blockHash];
    }
    
    function isBlockFinalized(bytes32 _blockHash) external view returns (bool) {
        return confirmations[_blockHash].isFinalized;
    }
    
    function getConfirmationCount(bytes32 _blockHash) external view returns (uint256) {
        return confirmations[_blockHash].confirmingValidators.length;
    }
    
    function getProposal(bytes32 _proposalHash) external view returns (
        address proposer,
        bytes32 dataHash,
        uint256 proposedAt,
        uint256 votesFor,
        uint256 votesAgainst,
        bool executed
    ) {
        Proposal storage p = proposals[_proposalHash];
        return (p.proposer, p.dataHash, p.proposedAt, p.votesFor, p.votesAgainst, p.executed);
    }
    
    function hasVoted(bytes32 _proposalHash, address _voter) external view returns (bool) {
        return proposals[_proposalHash].hasVoted[_voter];
    }
    
    function getRequiredConfirmations() external view returns (uint256) {
        return (validatorList.length * CONFIRMATION_THRESHOLD_NUM) / CONFIRMATION_THRESHOLD_DENOM;
    }
    
    // Allow receiving stake
    receive() external payable {
        revert("PoAConsensus: Use registerValidator");
    }
}
