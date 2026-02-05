// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TokenEngine
 * @dev Dual-token system for TerraCare Ledger v2.0
 * - MINE: Participation token (earned only, non-transferable initially)
 * - WELL: Utility token (bought or converted from MINE)
 */
contract TokenEngine is AccessControl, ReentrancyGuard {
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // MINE Token - Participation token (earned only)
    string public constant MINE_NAME = "TerraCare MINE";
    string public constant MINE_SYMBOL = "MINE";
    uint8 public constant DECIMALS = 18;
    
    // WELL Token - Utility token (bought or converted)
    string public constant WELL_NAME = "TerraCare WELL";
    string public constant WELL_SYMBOL = "WELL";
    
    // Token states
    mapping(address => uint256) private _mineBalances;
    mapping(address => uint256) private _wellBalances;
    mapping(address => mapping(address => uint256)) private _wellAllowances;
    
    // Total supplies
    uint256 public totalMineSupply;
    uint256 public totalWellSupply;
    
    // Conversion ratio: 100 MINE = 1 WELL (100:1)
    uint256 public constant CONVERSION_RATIO = 100;
    
    // MINE earning rate: 10 MINE per value point
    uint256 public constant MINE_PER_VALUE_POINT = 10 * 10**DECIMALS;
    
    // MINE transferability (initially false, can be enabled by governance)
    bool public mineTransferable = false;
    
    // Staking for governance
    struct StakeInfo {
        uint256 amount;
        uint256 stakedAt;
        uint256 lockEnd;
    }
    mapping(address => StakeInfo) public stakes;
    uint256 public totalStaked;
    
    // Events
    event MineMinted(address indexed to, uint256 amount, uint256 valuePoints);
    event MineBurned(address indexed from, uint256 amount);
    event WellMinted(address indexed to, uint256 amount, string source);
    event WellBurned(address indexed from, uint256 amount);
    event Converted(address indexed user, uint256 mineAmount, uint256 wellAmount);
    event MineTransferEnabled(bool enabled);
    event Staked(address indexed user, uint256 amount, uint256 lockEnd);
    event Unstaked(address indexed user, uint256 amount);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
    
    // ============ MINE Token Functions ============
    
    /**
     * @dev Mine activity and mint MINE tokens (called by ActivityRegistry)
     * @param to Address to receive MINE
     * @param valuePoints Value score of the activity (1-100 max per day)
     */
    function mineActivity(address to, uint256 valuePoints) external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 mineAmount = valuePoints * MINE_PER_VALUE_POINT;
        
        _mineBalances[to] += mineAmount;
        totalMineSupply += mineAmount;
        
        emit MineMinted(to, mineAmount, valuePoints);
        return mineAmount;
    }
    
    /**
     * @dev Batch mine activity for multiple users (gas efficient)
     */
    function batchMineActivity(
        address[] calldata recipients, 
        uint256[] calldata valuePoints
    ) external onlyRole(MINTER_ROLE) returns (uint256 totalMinted) {
        require(recipients.length == valuePoints.length, "Length mismatch");
        
        for (uint i = 0; i < recipients.length; i++) {
            uint256 mineAmount = valuePoints[i] * MINE_PER_VALUE_POINT;
            _mineBalances[recipients[i]] += mineAmount;
            totalMinted += mineAmount;
            emit MineMinted(recipients[i], mineAmount, valuePoints[i]);
        }
        totalMineSupply += totalMinted;
    }
    
    function balanceOfMINE(address account) external view returns (uint256) {
        return _mineBalances[account];
    }
    
    /**
     * @dev MINE transfers (initially restricted)
     */
    function transferMINE(address to, uint256 amount) external returns (bool) {
        require(mineTransferable || hasRole(ADMIN_ROLE, msg.sender), "MINE not transferable");
        require(_mineBalances[msg.sender] >= amount, "Insufficient MINE");
        
        _mineBalances[msg.sender] -= amount;
        _mineBalances[to] += amount;
        return true;
    }
    
    /**
     * @dev Enable MINE transfers (governance decision)
     */
    function setMineTransferable(bool enabled) external onlyRole(ADMIN_ROLE) {
        mineTransferable = enabled;
        emit MineTransferEnabled(enabled);
    }
    
    // ============ WELL Token Functions ============
    
    /**
     * @dev Convert MINE to WELL at 100:1 ratio
     * MINE is burned, WELL is minted
     */
    function convertMineToWell(uint256 mineAmount) external nonReentrant returns (uint256) {
        require(mineAmount >= CONVERSION_RATIO * 10**DECIMALS, "Minimum 100 MINE required");
        require(_mineBalances[msg.sender] >= mineAmount, "Insufficient MINE balance");
        
        uint256 wellAmount = mineAmount / CONVERSION_RATIO;
        
        // Burn MINE
        _mineBalances[msg.sender] -= mineAmount;
        totalMineSupply -= mineAmount;
        emit MineBurned(msg.sender, mineAmount);
        
        // Mint WELL
        _wellBalances[msg.sender] += wellAmount;
        totalWellSupply += wellAmount;
        emit WellMinted(msg.sender, wellAmount, "conversion");
        
        emit Converted(msg.sender, mineAmount, wellAmount);
        return wellAmount;
    }
    
    /**
     * @dev Purchase WELL with ETH (for revenue generation)
     * Price set by oracle/backend based on market conditions
     */
    function purchaseWell(address to, uint256 wellAmount) external onlyRole(MINTER_ROLE) {
        _wellBalances[to] += wellAmount;
        totalWellSupply += wellAmount;
        emit WellMinted(to, wellAmount, "purchase");
    }
    
    // Standard ERC20 functions for WELL
    function name() external pure returns (string memory) {
        return WELL_NAME;
    }
    
    function symbol() external pure returns (string memory) {
        return WELL_SYMBOL;
    }
    
    function decimals() external pure returns (uint8) {
        return DECIMALS;
    }
    
    function totalSupply() external view returns (uint256) {
        return totalWellSupply;
    }
    
    function balanceOf(address account) external view returns (uint256) {
        return _wellBalances[account];
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(_wellBalances[msg.sender] >= amount, "Insufficient WELL");
        _wellBalances[msg.sender] -= amount;
        _wellBalances[to] += amount;
        return true;
    }
    
    function allowance(address owner, address spender) external view returns (uint256) {
        return _wellAllowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        _wellAllowances[msg.sender][spender] = amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(_wellAllowances[from][msg.sender] >= amount, "Insufficient allowance");
        require(_wellBalances[from] >= amount, "Insufficient WELL");
        
        _wellAllowances[from][msg.sender] -= amount;
        _wellBalances[from] -= amount;
        _wellBalances[to] += amount;
        return true;
    }
    
    /**
     * @dev Burn WELL tokens
     */
    function burnWELL(uint256 amount) external {
        require(_wellBalances[msg.sender] >= amount, "Insufficient WELL");
        _wellBalances[msg.sender] -= amount;
        totalWellSupply -= amount;
        emit WellBurned(msg.sender, amount);
    }
    
    // ============ Staking for Governance ============
    
    /**
     * @dev Stake MINE for governance voting power
     * @param amount Amount of MINE to stake
     * @param lockPeriod Lock period in seconds (minimum 30 days for voting power)
     */
    function stakeMINE(uint256 amount, uint256 lockPeriod) external {
        require(_mineBalances[msg.sender] >= amount, "Insufficient MINE");
        require(amount > 0, "Cannot stake 0");
        
        _mineBalances[msg.sender] -= amount;
        
        StakeInfo storage stake = stakes[msg.sender];
        stake.amount += amount;
        stake.stakedAt = block.timestamp;
        stake.lockEnd = block.timestamp + lockPeriod;
        
        totalStaked += amount;
        
        emit Staked(msg.sender, amount, stake.lockEnd);
    }
    
    /**
     * @dev Unstake MINE after lock period
     */
    function unstakeMINE() external {
        StakeInfo storage stake = stakes[msg.sender];
        require(stake.amount > 0, "No stake found");
        require(block.timestamp >= stake.lockEnd, "Stake still locked");
        
        uint256 amount = stake.amount;
        totalStaked -= amount;
        
        delete stakes[msg.sender];
        
        _mineBalances[msg.sender] += amount;
        
        emit Unstaked(msg.sender, amount);
    }
    
    /**
     * @dev Get voting power (staked MINE amount)
     */
    function getVotingPower(address account) external view returns (uint256) {
        StakeInfo memory stake = stakes[account];
        // Only count stake if locked for at least 30 days
        if (stake.lockEnd >= block.timestamp + 30 days) {
            return stake.amount;
        }
        return 0;
    }
    
    /**
     * @dev Get combined balance (MINE + staked MINE)
     */
    function getTotalMINE(address account) external view returns (uint256) {
        return _mineBalances[account] + stakes[account].amount;
    }
    
    // ============ Admin Functions ============
    
    /**
     * @dev Emergency burn MINE (for anti-gaming/penalties)
     */
    function adminBurnMINE(address from, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(_mineBalances[from] >= amount, "Insufficient MINE");
        _mineBalances[from] -= amount;
        totalMineSupply -= amount;
        emit MineBurned(from, amount);
    }
    
    /**
     * @dev Grant minter role to ActivityRegistry
     */
    function grantMinterRole(address minter) external onlyRole(ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, minter);
    }
}
