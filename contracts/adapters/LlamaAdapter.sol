// SPDX-License-Identifier: MIT
// Pillar-1: AI audit trail with model versioning
// Pillar-2: First Principles: AI cannot hallucinate without traceability
// Pillar-3: Genius Channeled - Florence Nightingale (precision in data)
// Pillar-4: AI accountability as strategic dominance
// Pillar-5: Confidence scoring for AI outputs
// Pillar-6: Linked AI recommendations (Zettelkasten)
// Pillar-7: Build for AI regulatory compliance

pragma solidity ^0.8.24;

import "../SovereignIdentity.sol";
import "../AccessGovernor.sol";
import "../AuditTrail.sol";

/**
 * @title LlamaAdapter
 * @dev AI inference module adapter for Terracare
 *      - Model versioning on-chain
 *      - Recommendation audit trails
 *      - Confidence scoring with accountability
 *      - Input/output hash anchoring
 */
contract LlamaAdapter {
    // ============ Structs ============
    
    struct ModelVersion {
        bytes32 modelHash;          // Hash of model weights/config
        bytes32 trainingDataHash;   // Training dataset hash
        uint256 version;
        uint256 deployedAt;
        address deployedBy;
        bool active;
        bytes32 validationResults;  // Validation metrics hash
    }

    struct AIRecommendation {
        bytes32 recommendationHash;
        bytes32 inputHash;          // Hash of input data (never raw data)
        bytes32 outputHash;         // Hash of AI output
        bytes32 modelHash;          // Model used
        uint256 confidenceScore;    // 0-10000 (0-100% with 2 decimals)
        uint256 createdAt;
        address patient;
        bytes32 contextHash;        // Context/prompt hash
        bytes32[] relatedRecommendations;
    }

    struct InferenceSession {
        bytes32 sessionHash;
        address patient;
        bytes32 modelHash;
        uint256 startedAt;
        uint256 completedAt;
        uint256 recommendationCount;
        bytes32 sessionSummaryHash;
    }

    // ============ State ============
    
    SovereignIdentity public identity;
    AccessGovernor public accessGovernor;
    AuditTrail public auditTrail;
    
    address public governance;
    
    // Model hash => ModelVersion
    mapping(bytes32 => ModelVersion) public models;
    bytes32[] public modelList;
    bytes32 public activeModel;
    
    // Recommendation hash => AIRecommendation
    mapping(bytes32 => AIRecommendation) public recommendations;
    mapping(address => bytes32[]) public patientRecommendations;
    
    // Session hash => InferenceSession
    mapping(bytes32 => InferenceSession) public sessions;
    
    // Authorized AI operators
    mapping(address => bool) public authorizedOperators;
    
    // Minimum confidence threshold
    uint256 public minConfidenceThreshold = 5000; // 50%

    // ============ Events ============
    
    event ModelRegistered(
        bytes32 indexed modelHash,
        uint256 version,
        address deployedBy
    );
    
    event ModelActivated(bytes32 indexed modelHash);
    
    event RecommendationGenerated(
        bytes32 indexed recommendationHash,
        address indexed patient,
        bytes32 modelHash,
        uint256 confidenceScore
    );
    
    event InferenceSessionStarted(
        bytes32 indexed sessionHash,
        address indexed patient,
        bytes32 modelHash
    );
    
    event InferenceSessionCompleted(
        bytes32 indexed sessionHash,
        uint256 recommendationCount
    );

    // ============ Modifiers ============
    
    modifier onlyGovernance() {
        require(msg.sender == governance, "LlamaAdapter: Not governance");
        _;
    }

    modifier onlyAuthorizedOperator() {
        require(
            authorizedOperators[msg.sender] || msg.sender == governance,
            "LlamaAdapter: Not authorized"
        );
        _;
    }

    // ============ Constructor ============
    
    constructor(
        address _identity,
        address _accessGovernor,
        address _auditTrail
    ) {
        identity = SovereignIdentity(_identity);
        accessGovernor = AccessGovernor(_accessGovernor);
        auditTrail = AuditTrail(_auditTrail);
        governance = msg.sender;
    }

    // ============ Model Management ============
    
    /**
     * @dev Register new AI model version
     */
    function registerModel(
        bytes32 modelHash,
        bytes32 trainingDataHash,
        uint256 version,
        bytes32 validationResults
    ) external onlyGovernance {
        require(models[modelHash].deployedAt == 0, "LlamaAdapter: Model exists");

        models[modelHash] = ModelVersion({
            modelHash: modelHash,
            trainingDataHash: trainingDataHash,
            version: version,
            deployedAt: block.timestamp,
            deployedBy: msg.sender,
            active: false,
            validationResults: validationResults
        });

        modelList.push(modelHash);

        auditTrail.createEntry(
            address(0),
            SovereignIdentity.SystemType.LlamaBackend,
            keccak256("MODEL_REGISTERED"),
            modelHash,
            new bytes32[](0)
        );

        emit ModelRegistered(modelHash, version, msg.sender);
    }

    /**
     * @dev Activate model for inference
     */
    function activateModel(bytes32 modelHash) external onlyGovernance {
        require(models[modelHash].deployedAt != 0, "LlamaAdapter: Model not found");
        
        // Deactivate current
        if (activeModel != bytes32(0)) {
            models[activeModel].active = false;
        }

        models[modelHash].active = true;
        activeModel = modelHash;

        auditTrail.createEntry(
            address(0),
            SovereignIdentity.SystemType.LlamaBackend,
            keccak256("MODEL_ACTIVATED"),
            modelHash,
            new bytes32[](0)
        );

        emit ModelActivated(modelHash);
    }

    // ============ Inference Sessions ============
    
    /**
     * @dev Start inference session
     */
    function startSession(
        bytes32 sessionHash,
        address patient
    ) external onlyAuthorizedOperator {
        require(
            identity.getProfile(patient).status == SovereignIdentity.IdentityStatus.Active,
            "LlamaAdapter: Patient not active"
        );
        require(activeModel != bytes32(0), "LlamaAdapter: No active model");
        require(sessions[sessionHash].startedAt == 0, "LlamaAdapter: Session exists");

        sessions[sessionHash] = InferenceSession({
            sessionHash: sessionHash,
            patient: patient,
            modelHash: activeModel,
            startedAt: block.timestamp,
            completedAt: 0,
            recommendationCount: 0,
            sessionSummaryHash: bytes32(0)
        });

        // Link identity
        if (identity.getSystemIdentity(patient, SovereignIdentity.SystemType.LlamaBackend).systemId == bytes32(0)) {
            identity.linkSystem(patient, SovereignIdentity.SystemType.LlamaBackend, sessionHash);
        }

        auditTrail.createEntry(
            patient,
            SovereignIdentity.SystemType.LlamaBackend,
            keccak256("INFERENCE_SESSION_STARTED"),
            sessionHash,
            new bytes32[](0)
        );

        emit InferenceSessionStarted(sessionHash, patient, activeModel);
    }

    /**
     * @dev Record AI recommendation - every output anchored
     * Pillar-2: AI cannot hallucinate without traceability
     */
    function recordRecommendation(
        bytes32 recommendationHash,
        bytes32 sessionHash,
        address patient,
        bytes32 inputHash,
        bytes32 outputHash,
        uint256 confidenceScore,
        bytes32 contextHash,
        bytes32[] calldata relatedRecommendations
    ) external onlyAuthorizedOperator {
        require(sessions[sessionHash].startedAt != 0, "LlamaAdapter: Session not found");
        require(recommendations[recommendationHash].createdAt == 0, "LlamaAdapter: Recommendation exists");
        require(confidenceScore >= minConfidenceThreshold, "LlamaAdapter: Below threshold");

        recommendations[recommendationHash] = AIRecommendation({
            recommendationHash: recommendationHash,
            inputHash: inputHash,
            outputHash: outputHash,
            modelHash: activeModel,
            confidenceScore: confidenceScore,
            createdAt: block.timestamp,
            patient: patient,
            contextHash: contextHash,
            relatedRecommendations: relatedRecommendations
        });

        patientRecommendations[patient].push(recommendationHash);
        sessions[sessionHash].recommendationCount++;

        auditTrail.createEntry(
            patient,
            SovereignIdentity.SystemType.LlamaBackend,
            keccak256("RECOMMENDATION_GENERATED"),
            recommendationHash,
            relatedRecommendations
        );

        emit RecommendationGenerated(recommendationHash, patient, activeModel, confidenceScore);
    }

    /**
     * @dev Complete inference session
     */
    function completeSession(
        bytes32 sessionHash,
        bytes32 sessionSummaryHash
    ) external onlyAuthorizedOperator {
        InferenceSession storage session = sessions[sessionHash];
        require(session.startedAt != 0, "LlamaAdapter: Session not found");
        require(session.completedAt == 0, "LlamaAdapter: Already completed");

        session.completedAt = block.timestamp;
        session.sessionSummaryHash = sessionSummaryHash;

        auditTrail.createEntry(
            session.patient,
            SovereignIdentity.SystemType.LlamaBackend,
            keccak256("INFERENCE_SESSION_COMPLETED"),
            sessionHash,
            new bytes32[](0)
        );

        emit InferenceSessionCompleted(sessionHash, session.recommendationCount);
    }

    // ============ Operator Management ============
    
    function authorizeOperator(address operator) external onlyGovernance {
        authorizedOperators[operator] = true;
    }

    function revokeOperator(address operator) external onlyGovernance {
        authorizedOperators[operator] = false;
    }

    function setMinConfidenceThreshold(uint256 threshold) external onlyGovernance {
        minConfidenceThreshold = threshold;
    }

    // ============ View Functions ============
    
    function getModel(bytes32 modelHash) external view returns (ModelVersion memory) {
        return models[modelHash];
    }

    function getActiveModel() external view returns (ModelVersion memory) {
        return models[activeModel];
    }

    function getRecommendation(bytes32 recommendationHash) external view returns (AIRecommendation memory) {
        return recommendations[recommendationHash];
    }

    function getPatientRecommendations(address patient) external view returns (bytes32[] memory) {
        return patientRecommendations[patient];
    }

    function getSession(bytes32 sessionHash) external view returns (InferenceSession memory) {
        return sessions[sessionHash];
    }

    function getModelCount() external view returns (uint256) {
        return modelList.length;
    }
}
