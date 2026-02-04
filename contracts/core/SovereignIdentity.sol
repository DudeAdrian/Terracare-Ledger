// SPDX-License-Identifier: MIT
/**
 * @title SovereignIdentity
 * @notice Diamond-based soulbound identity registry for Terracare Ledger
 * 
 * INSPIRED BY:
 * - Pillar 1 (Underground Knowledge): Stealth addresses, Merkleized access
 * - Pillar 3 (Reverse-Engineer Genius): Vitalik's account abstraction, Szabo's smart contracts
 * - Pillar 7 (Billionaire Mindset): Build for centuries, own the permissions layer
 * 
 * ARCHITECTURE:
 * - EIP-2535 Diamond Standard for upgradeability
 * - ERC-5192 Soulbound tokens for non-transferable medical credentials
 * - ERC-2771 Meta-transaction support for gasless operations
 * - 9-Layer integration: Links all sibling systems
 */
pragma solidity ^0.8.24;

import {IERC5192} from "@openzeppelin/contracts/interfaces/IERC5192.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC2771Context} from "@openzeppelin/contracts/metatx/IERC2771Context.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

/**
 * @notice Diamond Storage for SovereignIdentity
 * @dev Isolated storage following Diamond pattern
 */
library SovereignIdentityStorage {
    bytes32 constant STORAGE_POSITION = keccak256("terracare.sovereignidentity.storage");
    
    // System identifiers for 9-layer integration
    enum SystemType {
        Heartware,      // UI/Galaxy visualization
        Tholos,         // Clinical records
        Harmonic,       // Biofeedback/sacred geometry
        Terratone,      // Frequency therapy
        SofieOS,        // Operating system layer
        SofieLlama,     // AI inference
        SofieMap,       // Geo-spatial
        Sandiron,       // Validator nodes
        Terracare       // This ledger
    }
    
    struct Identity {
        bytes32 identityHash;           // keccak256 of off-chain identity
        bytes32 publicKey;              // For stealth address derivation (EIP-5564)
        uint256 createdAt;
        uint256 lastActivity;
        bool isActive;
        mapping(SystemType => bytes32) systemBindings;  // Cross-system links
        mapping(bytes32 => bool) credentials;           // Soulbound certs
    }
    
    struct Storage {
        // Soulbound token state
        mapping(uint256 => address) owners;
        mapping(address => uint256) balances;
        mapping(uint256 => address) tokenApprovals;
        mapping(address => mapping(address => bool)) operatorApprovals;
        mapping(uint256 => bool) lockedTokens;  // ERC-5192 soulbound
        
        // Identity registry
        mapping(address => Identity) identities;
        mapping(uint256 => address) tokenToIdentity;
        uint256 totalSupply;
        uint256 nextTokenId;
        
        // Stealth address registry (EIP-5564)
        mapping(bytes32 => address) stealthRegistry;
        mapping(address => bytes32[]) userStealthAddresses;
        
        // Dead man's switch
        mapping(address => uint256) inactivityThreshold;  // Default 90 days
        mapping(address => address) emergencyContact;
        
        // ERC-2771 trusted forwarders
        mapping(address => bool) trustedForwarders;
        
        // URI
        string baseURI;
    }
    
    function getStorage() internal pure returns (Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}

/**
 * @notice Events optimized for Heartware indexing
 */
interface ISovereignIdentityEvents {
    /// @notice Emitted when new sovereign identity is minted
    event IdentityMinted(
        address indexed owner,
        uint256 indexed tokenId,
        bytes32 indexed identityHash,
        uint256 timestamp
    );
    
    /// @notice Emitted when identity binds to a sibling system
    event SystemBindingUpdated(
        address indexed identity,
        SovereignIdentityStorage.SystemType indexed system,
        bytes32 indexed bindingHash,
        uint256 timestamp
    );
    
    /// @notice Emitted when soulbound credential is issued
    event CredentialIssued(
        address indexed identity,
        bytes32 indexed credentialHash,
        bytes32 indexed issuerHash,
        uint256 timestamp
    );
    
    /// @notice Emitted when stealth address is registered (EIP-5564)
    event StealthAddressRegistered(
        address indexed registrant,
        bytes32 indexed stealthPubKey,
        bytes32 indexed viewTag,
        uint256 timestamp
    );
    
    /// @notice Emitted when dead man's switch is triggered
    event InactivityAlert(
        address indexed identity,
        uint256 lastActivity,
        uint256 threshold,
        uint256 timestamp
    );
    
    /// @notice ERC-5192 Soulbound events
    event Locked(uint256 indexed tokenId);
    event Unlocked(uint256 indexed tokenId);
}

/**
 * @title SovereignIdentity Facet
 * @notice Diamond facet for sovereign identity management
 */
contract SovereignIdentity is IERC5192, IERC721Metadata, ISovereignIdentityEvents {
    
    string public constant name = "Terracare Sovereign Identity";
    string public constant symbol = "TSI";
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }
    
    modifier validIdentity(address _addr) {
        require(hasIdentity(_addr), "SovereignIdentity: No identity found");
        _;
    }
    
    // ============ ERC-2771 Meta-Transaction Support ============
    
    /**
     * @notice Returns the actual sender for meta-transactions
     * @dev Implements ERC-2771 context extraction
     */
    function _msgSender() internal view returns (address) {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        uint256 calldataLength = msg.data.length;
        
        if (calldataLength >= 20 && s.trustedForwarders[msg.sender]) {
            // Extract sender from end of calldata (ERC-2771)
            address sender;
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
            return sender;
        }
        return msg.sender;
    }
    
    // ============ Identity Management ============
    
    /**
     * @notice Mint new sovereign identity (soulbound)
     * @param _identityHash keccak256 hash of off-chain identity data
     * @param _publicKey For stealth address derivation
     * @return tokenId The minted soulbound token ID
     * 
     * INSPIRED BY: Vitalik's account abstraction - gasless-ready identity
     */
    function mintIdentity(
        bytes32 _identityHash,
        bytes32 _publicKey
    ) external returns (uint256 tokenId) {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        address sender = _msgSender();
        
        require(s.identities[sender].createdAt == 0, "SovereignIdentity: Already has identity");
        require(_identityHash != bytes32(0), "SovereignIdentity: Invalid hash");
        
        tokenId = s.nextTokenId++;
        
        s.owners[tokenId] = sender;
        s.balances[sender] = 1;
        s.lockedTokens[tokenId] = true;  // Soulbound
        
        SovereignIdentityStorage.Identity storage identity = s.identities[sender];
        identity.identityHash = _identityHash;
        identity.publicKey = _publicKey;
        identity.createdAt = block.timestamp;
        identity.lastActivity = block.timestamp;
        identity.isActive = true;
        
        s.totalSupply++;
        
        emit IdentityMinted(sender, tokenId, _identityHash, block.timestamp);
        emit Locked(tokenId);
        
        return tokenId;
    }
    
    /**
     * @notice Bind identity to a sibling system
     * @param _system The system type (0-8 for 9 layers)
     * @param _bindingHash Hash of the binding data
     */
    function bindToSystem(
        SovereignIdentityStorage.SystemType _system,
        bytes32 _bindingHash
    ) external validIdentity(_msgSender()) {
        address sender = _msgSender();
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        
        s.identities[sender].systemBindings[_system] = _bindingHash;
        s.identities[sender].lastActivity = block.timestamp;
        
        emit SystemBindingUpdated(sender, _system, _bindingHash, block.timestamp);
    }
    
    /**
     * @notice Issue soulbound credential to identity
     * @param _to Identity to receive credential
     * @param _credentialHash Hash of credential data
     * @param _issuerHash Hash of issuing authority
     */
    function issueCredential(
        address _to,
        bytes32 _credentialHash,
        bytes32 _issuerHash
    ) external validIdentity(_to) {
        // In production, verify issuer is authorized
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        
        s.identities[_to].credentials[_credentialHash] = true;
        s.identities[_to].lastActivity = block.timestamp;
        
        emit CredentialIssued(_to, _credentialHash, _issuerHash, block.timestamp);
    }
    
    /**
     * @notice Register stealth address for privacy (EIP-5564)
     * @param _stealthPubKey Public key for stealth address
     * @param _viewTag Tag for scanning
     */
    function registerStealthAddress(
        bytes32 _stealthPubKey,
        bytes32 _viewTag
    ) external validIdentity(_msgSender()) {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        address sender = _msgSender();
        
        s.stealthRegistry[_stealthPubKey] = sender;
        s.userStealthAddresses[sender].push(_stealthPubKey);
        s.identities[sender].lastActivity = block.timestamp;
        
        emit StealthAddressRegistered(sender, _stealthPubKey, _viewTag, block.timestamp);
    }
    
    /**
     * @notice Update activity timestamp (called by other facets)
     */
    function touchActivity(address _identity) external {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        s.identities[_identity].lastActivity = block.timestamp;
    }
    
    // ============ View Functions ============
    
    function hasIdentity(address _addr) public view returns (bool) {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        return s.identities[_addr].isActive;
    }
    
    function getIdentityHash(address _addr) external view returns (bytes32) {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        return s.identities[_addr].identityHash;
    }
    
    function getSystemBinding(
        address _addr,
        SovereignIdentityStorage.SystemType _system
    ) external view returns (bytes32) {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        return s.identities[_addr].systemBindings[_system];
    }
    
    function getLastActivity(address _addr) external view returns (uint256) {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        return s.identities[_addr].lastActivity;
    }
    
    /**
     * @notice Check if dead man's switch should trigger
     * @param _addr Identity to check
     * @return shouldTrigger True if inactivity threshold exceeded
     */
    function checkInactivity(address _addr) external returns (bool shouldTrigger) {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        SovereignIdentityStorage.Identity storage identity = s.identities[_addr];
        
        uint256 threshold = s.inactivityThreshold[_addr];
        if (threshold == 0) threshold = 90 days;  // Default 90 days
        
        shouldTrigger = (block.timestamp - identity.lastActivity) > threshold;
        
        if (shouldTrigger) {
            emit InactivityAlert(_addr, identity.lastActivity, threshold, block.timestamp);
        }
        
        return shouldTrigger;
    }
    
    // ============ ERC-5192 Soulbound Implementation ============
    
    function locked(uint256 tokenId) external view override returns (bool) {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        return s.lockedTokens[tokenId];
    }
    
    // ============ ERC-721 Implementation (Soulbound - transfers disabled) ============
    
    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "ERC721: zero address");
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        return s.balances[owner];
    }
    
    function ownerOf(uint256 tokenId) external view override returns (address) {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        address owner = s.owners[tokenId];
        require(owner != address(0), "ERC721: nonexistent token");
        return owner;
    }
    
    function approve(address, uint256) external pure override {
        revert("SovereignIdentity: soulbound - transfers disabled");
    }
    
    function getApproved(uint256) external pure override returns (address) {
        return address(0);
    }
    
    function setApprovalForAll(address, bool) external pure override {
        revert("SovereignIdentity: soulbound - transfers disabled");
    }
    
    function isApprovedForAll(address, address) external pure override returns (bool) {
        return false;
    }
    
    function transferFrom(address, address, uint256) external pure override {
        revert("SovereignIdentity: soulbound - transfers disabled");
    }
    
    function safeTransferFrom(address, address, uint256) external pure override {
        revert("SovereignIdentity: soulbound - transfers disabled");
    }
    
    function safeTransferFrom(address, address, uint256, bytes calldata) external pure override {
        revert("SovereignIdentity: soulbound - transfers disabled");
    }
    
    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        require(s.owners[tokenId] != address(0), "ERC721: nonexistent token");
        
        // Return IPFS hash pointer for off-chain metadata
        return string(abi.encodePacked("ipfs://terracare/identity/", uint256ToHex(tokenId)));
    }
    
    // ============ Admin Functions ============
    
    function setTrustedForwarder(address _forwarder, bool _trusted) external onlyOwner {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        s.trustedForwarders[_forwarder] = _trusted;
    }
    
    function setInactivityThreshold(address _identity, uint256 _threshold) external onlyOwner {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        s.inactivityThreshold[_identity] = _threshold;
    }
    
    function setEmergencyContact(address _contact) external validIdentity(_msgSender()) {
        SovereignIdentityStorage.Storage storage s = SovereignIdentityStorage.getStorage();
        s.emergencyContact[_msgSender()] = _contact;
    }
    
    // ============ Utilities ============
    
    function uint256ToHex(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp >>= 4;
        }
        
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            uint256 digit = value & 0xf;
            if (digit < 10) {
                buffer[digits] = bytes1(uint8(digit + 48));
            } else {
                buffer[digits] = bytes1(uint8(digit + 87));
            }
            value >>= 4;
        }
        
        return string(buffer);
    }
}
