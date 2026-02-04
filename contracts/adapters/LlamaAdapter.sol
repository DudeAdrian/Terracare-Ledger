// SPDX-License-Identifier: MIT
/**
 * @title LlamaAdapter
 * @notice Bridge for AI inference audit trails
 * @dev Records AI model inferences and recommendations for accountability
 */
pragma solidity ^0.8.24;

contract LlamaAdapter {
    
    // ============ Types ============
    
    enum InferenceType {
        Diagnostic,
        Recommendation,
        Analysis,
        Prediction,
        Summarization,
        ChatResponse
    }
    
    enum ConfidenceLevel {
        Low,        // < 70%
        Medium,     // 70-85%
        High,       // 85-95%
        VeryHigh    // > 95%
    }
    
    struct InferenceRecord {
        bytes32 inferenceHash;      // Hash of inference data
        bytes32 modelHash;          // AI model version hash
        bytes32 inputHash;          // Hash of input/prompt
        bytes32 outputHash;         // Hash of output/response
        InferenceType inferenceType;
        ConfidenceLevel confidence;
        address operator;           // Who triggered the inference
        uint256 timestamp;
        bool hasHumanReview;        // Was this reviewed by human
        bytes32 reviewerHash;       // Reviewer identity hash (if reviewed)
    }
    
    struct ModelVersion {
        bytes32 modelHash;
        string modelName;
        uint256 version;
        bytes32 trainingDataHash;   // Hash of training dataset manifest
        uint256 trainedAt;
        bool isApproved;
    }
    
    // ============ Storage ============
    
    address public sovereignIdentity;
    address public accessGovernor;
    address public auditTrail;
    
    // Inference hash => record
    mapping(bytes32 => InferenceRecord) public inferences;
    
    // User identity => inference hashes
    mapping(bytes32 => bytes32[]) public userInferences;
    
    // Model hash => model info
    mapping(bytes32 => ModelVersion) public models;
    
    // Authorized AI operators
    mapping(address => bool) public authorizedOperators;
    
    // Approved model hashes
    bytes32[] public approvedModels;
    
    // ============ Events ============
    
    event InferenceRecorded(
        bytes32 indexed inferenceHash,
        bytes32 indexed modelHash,
        InferenceType inferenceType,
        ConfidenceLevel confidence,
        address operator,
        uint256 timestamp
    );
    
    event ModelRegistered(
        bytes32 indexed modelHash,
        string modelName,
        uint256 version,
        uint256 trainedAt
    );
    
    event ModelApproved(bytes32 indexed modelHash, address approver);
    
    event InferenceReviewed(
        bytes32 indexed inferenceHash,
        bytes32 indexed reviewerHash,
        bool approved,
        uint256 timestamp
    );
    
    // ============ Modifiers ============
    
    modifier onlyAuthorizedOperator() {
        require(authorizedOperators[msg.sender], "LlamaAdapter: Not authorized");
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
        authorizedOperators[msg.sender] = true;
    }
    
    // ============ Admin Functions ============
    
    function addOperator(address operator) external {
        require(
            msg.sender == accessGovernor || msg.sender == sovereignIdentity,
            "LlamaAdapter: Not authorized"
        );
        authorizedOperators[operator] = true;
    }
    
    function removeOperator(address operator) external {
        require(
            msg.sender == accessGovernor || msg.sender == sovereignIdentity,
            "LlamaAdapter: Not authorized"
        );
        authorizedOperators[operator] = false;
    }
    
    // ============ Model Management ============
    
    function registerModel(
        bytes32 _modelHash,
        string calldata _modelName,
        uint256 _version,
        bytes32 _trainingDataHash
    ) external onlyAuthorizedOperator returns (bool) {
        require(_modelHash != bytes32(0), "LlamaAdapter: Invalid model hash");
        require(models[_modelHash].modelHash == bytes32(0), "LlamaAdapter: Model exists");
        
        ModelVersion memory model = ModelVersion({
            modelHash: _modelHash,
            modelName: _modelName,
            version: _version,
            trainingDataHash: _trainingDataHash,
            trainedAt: block.timestamp,
            isApproved: false
        });
        
        models[_modelHash] = model;
        
        emit ModelRegistered(_modelHash, _modelName, _version, block.timestamp);
        
        return true;
    }
    
    function approveModel(bytes32 _modelHash) external {
        require(
            msg.sender == accessGovernor || msg.sender == sovereignIdentity,
            "LlamaAdapter: Not authorized"
        );
        require(models[_modelHash].modelHash != bytes32(0), "LlamaAdapter: Model not found");
        
        models[_modelHash].isApproved = true;
        approvedModels.push(_modelHash);
        
        emit ModelApproved(_modelHash, msg.sender);
    }
    
    // ============ Inference Recording ============
    
    function recordInference(
        bytes32 _inferenceHash,
        bytes32 _modelHash,
        bytes32 _inputHash,
        bytes32 _outputHash,
        InferenceType _inferenceType,
        ConfidenceLevel _confidence,
        bytes32 _userIdentity
    ) external onlyAuthorizedOperator returns (bool) {
        require(_inferenceHash != bytes32(0), "LlamaAdapter: Invalid inference hash");
        require(inferences[_inferenceHash].inferenceHash == bytes32(0), "LlamaAdapter: Inference exists");
        require(models[_modelHash].isApproved, "LlamaAdapter: Model not approved");
        
        InferenceRecord memory record = InferenceRecord({
            inferenceHash: _inferenceHash,
            modelHash: _modelHash,
            inputHash: _inputHash,
            outputHash: _outputHash,
            inferenceType: _inferenceType,
            confidence: _confidence,
            operator: msg.sender,
            timestamp: block.timestamp,
            hasHumanReview: false,
            reviewerHash: bytes32(0)
        });
        
        inferences[_inferenceHash] = record;
        userInferences[_userIdentity].push(_inferenceHash);
        
        emit InferenceRecorded(
            _inferenceHash,
            _modelHash,
            _inferenceType,
            _confidence,
            msg.sender,
            block.timestamp
        );
        
        return true;
    }
    
    function recordHumanReview(
        bytes32 _inferenceHash,
        bytes32 _reviewerHash,
        bool _approved
    ) external onlyAuthorizedOperator {
        InferenceRecord storage record = inferences[_inferenceHash];
        require(record.inferenceHash != bytes32(0), "LlamaAdapter: Inference not found");
        
        record.hasHumanReview = true;
        record.reviewerHash = _reviewerHash;
        
        emit InferenceReviewed(_inferenceHash, _reviewerHash, _approved, block.timestamp);
    }
    
    // ============ View Functions ============
    
    function getInference(bytes32 _inferenceHash) external view returns (InferenceRecord memory) {
        return inferences[_inferenceHash];
    }
    
    function getUserInferences(bytes32 _userIdentity) external view returns (bytes32[] memory) {
        return userInferences[_userIdentity];
    }
    
    function getModel(bytes32 _modelHash) external view returns (ModelVersion memory) {
        return models[_modelHash];
    }
    
    function getApprovedModels() external view returns (bytes32[] memory) {
        return approvedModels;
    }
    
    function isModelApproved(bytes32 _modelHash) external view returns (bool) {
        return models[_modelHash].isApproved;
    }
}
