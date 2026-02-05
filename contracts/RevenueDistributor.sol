// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TokenEngine.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title RevenueDistributor
 * @dev Cooperative revenue distribution for TerraCare Ledger v2.0
 * - Splits incoming revenue per cooperative model
 * - SEAL investor repayment with 3-5x cap
 * - Automatic stop when investor cap reached
 */
contract RevenueDistributor is AccessControl, ReentrancyGuard {
    
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    
    TokenEngine public tokenEngine;
    
    // Revenue split percentages (must sum to 100%)
    struct RevenueSplit {
        uint256 userBuybacks;      // 30% - User token buybacks
        uint256 investorRepayment; // 20% - SEAL investor repayment
        uint256 operations;        // 40% - Platform operations
        uint256 reserve;           // 10% - Emergency reserve
    }
    
    RevenueSplit public split = RevenueSplit({
        userBuybacks: 30,
        investorRepayment: 20,
        operations: 40,
        reserve: 10
    });
    
    uint256 public constant PERCENTAGE_BASE = 100;
    
    // SEAL Investor tracking
    struct SEALInvestor {
        address investorAddress;
        uint256 initialInvestment;  // Original investment amount
        uint256 repaymentCap;       // 3-5x initial investment
        uint256 paidAmount;         // Amount repaid so far
        bool capReached;            // Whether cap has been reached
        uint256 investmentDate;     // When investment was made
    }
    
    SEALInvestor[] public sealInvestors;
    mapping(address => uint256) public investorIndex;
    uint256 public totalSEALInvested;
    uint256 public totalSEALPaid;
    
    // Treasury addresses
    address public userBuybackTreasury;
    address public operationsTreasury;
    address public reserveTreasury;
    
    // Revenue tracking
    uint256 public totalRevenueReceived;
    uint256 public totalDistributedToUsers;
    uint256 public totalDistributedToInvestors;
    uint256 public totalDistributedToOperations;
    uint256 public totalDistributedToReserve;
    
    // Buyback mechanism
    uint256 public wellBuybackPrice;  // Price in wei per WELL token
    bool public buybacksEnabled = true;
    
    // Events
    event RevenueReceived(uint256 amount, string source);
    event RevenueDistributed(
        uint256 userBuybackAmount,
        uint256 investorAmount,
        uint256 operationsAmount,
        uint256 reserveAmount
    );
    event SEALInvestorAdded(address indexed investor, uint256 investment, uint256 cap);
    event SEALRepayment(address indexed investor, uint256 amount, uint256 totalPaid);
    event SEALCapReached(address indexed investor, uint256 totalRepaid);
    event TokensBoughtBack(address indexed user, uint256 wellAmount, uint256 payment);
    event SplitUpdated(uint256 userBuybacks, uint256 investorRepayment, uint256 operations, uint256 reserve);
    
    constructor(
        address _tokenEngine,
        address _userBuybackTreasury,
        address _operationsTreasury,
        address _reserveTreasury
    ) {
        require(_tokenEngine != address(0), "Invalid TokenEngine");
        require(_userBuybackTreasury != address(0), "Invalid user treasury");
        require(_operationsTreasury != address(0), "Invalid operations treasury");
        require(_reserveTreasury != address(0), "Invalid reserve treasury");
        
        tokenEngine = TokenEngine(_tokenEngine);
        userBuybackTreasury = _userBuybackTreasury;
        operationsTreasury = _operationsTreasury;
        reserveTreasury = _reserveTreasury;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
        
        // Default WELL price: 0.001 ETH per WELL
        wellBuybackPrice = 0.001 ether;
    }
    
    /**
     * @dev Add SEAL investor
     * @param investor Investor wallet address
     * @param investmentAmount Initial investment in wei
     * @param capMultiplier Multiplier for repayment cap (300-500 for 3x-5x)
     */
    function addSEALInvestor(
        address investor,
        uint256 investmentAmount,
        uint256 capMultiplier
    ) external onlyRole(ADMIN_ROLE) {
        require(investor != address(0), "Invalid investor address");
        require(investmentAmount > 0, "Investment must be > 0");
        require(capMultiplier >= 300 && capMultiplier <= 500, "Cap must be 3x-5x");
        require(investorIndex[investor] == 0 && sealInvestors.length == 0 || 
                investorIndex[investor] == 0 && sealInvestors[0].investorAddress != investor, 
                "Investor already exists");
        
        uint256 repaymentCap = (investmentAmount * capMultiplier) / 100;
        
        sealInvestors.push(SEALInvestor({
            investorAddress: investor,
            initialInvestment: investmentAmount,
            repaymentCap: repaymentCap,
            paidAmount: 0,
            capReached: false,
            investmentDate: block.timestamp
        }));
        
        investorIndex[investor] = sealInvestors.length;
        totalSEALInvested += investmentAmount;
        
        emit SEALInvestorAdded(investor, investmentAmount, repaymentCap);
    }
    
    /**
     * @dev Receive and distribute revenue (called by webhook/oracle)
     */
    function distribute() external payable onlyRole(DISTRIBUTOR_ROLE) nonReentrant {
        require(msg.value > 0, "No revenue to distribute");
        
        totalRevenueReceived += msg.value;
        
        // Calculate splits
        uint256 userBuybackAmount = (msg.value * split.userBuybacks) / PERCENTAGE_BASE;
        uint256 investorAmount = (msg.value * split.investorRepayment) / PERCENTAGE_BASE;
        uint256 operationsAmount = (msg.value * split.operations) / PERCENTAGE_BASE;
        uint256 reserveAmount = msg.value - userBuybackAmount - investorAmount - operationsAmount;
        
        // Send to operations treasury
        (bool opsSuccess, ) = operationsTreasury.call{value: operationsAmount}("");
        require(opsSuccess, "Operations transfer failed");
        totalDistributedToOperations += operationsAmount;
        
        // Send to reserve treasury
        (bool resSuccess, ) = reserveTreasury.call{value: reserveAmount}("");
        require(resSuccess, "Reserve transfer failed");
        totalDistributedToReserve += reserveAmount;
        
        // Distribute to investors (respecting caps)
        uint256 actualInvestorDistribution = _distributeToInvestors(investorAmount);
        totalDistributedToInvestors += actualInvestorDistribution;
        
        // Remaining investor amount goes to user buybacks
        uint256 totalUserAmount = userBuybackAmount + (investorAmount - actualInvestorDistribution);
        
        // Send to user buyback treasury
        (bool buybackSuccess, ) = userBuybackTreasury.call{value: totalUserAmount}("");
        require(buybackSuccess, "Buyback transfer failed");
        totalDistributedToUsers += totalUserAmount;
        
        emit RevenueReceived(msg.value, "webhook");
        emit RevenueDistributed(totalUserAmount, actualInvestorDistribution, operationsAmount, reserveAmount);
    }
    
    /**
     * @dev Distribute to investors respecting SEAL caps
     */
    function _distributeToInvestors(uint256 amount) internal returns (uint256 actuallyDistributed) {
        if (sealInvestors.length == 0 || amount == 0) {
            return 0;
        }
        
        // Count active investors (those who haven't reached cap)
        uint256 activeInvestorCount = 0;
        for (uint i = 0; i < sealInvestors.length; i++) {
            if (!sealInvestors[i].capReached) {
                activeInvestorCount++;
            }
        }
        
        if (activeInvestorCount == 0) {
            return 0; // All investors have reached their caps
        }
        
        uint256 perInvestor = amount / activeInvestorCount;
        
        for (uint i = 0; i < sealInvestors.length; i++) {
            if (sealInvestors[i].capReached) continue;
            
            SEALInvestor storage investor = sealInvestors[i];
            uint256 remainingToCap = investor.repaymentCap - investor.paidAmount;
            uint256 payment = perInvestor > remainingToCap ? remainingToCap : perInvestor;
            
            // Send payment
            (bool success, ) = investor.investorAddress.call{value: payment}("");
            if (success) {
                investor.paidAmount += payment;
                actuallyDistributed += payment;
                totalSEALPaid += payment;
                
                emit SEALRepayment(investor.investorAddress, payment, investor.paidAmount);
                
                // Check if cap reached
                if (investor.paidAmount >= investor.repaymentCap) {
                    investor.capReached = true;
                    emit SEALCapReached(investor.investorAddress, investor.paidAmount);
                }
            }
        }
    }
    
    /**
     * @dev Buy back WELL tokens from user (user sells WELL for ETH)
     * @param wellAmount Amount of WELL to sell
     */
    function sellWell(uint256 wellAmount) external nonReentrant {
        require(buybacksEnabled, "Buybacks disabled");
        require(wellAmount > 0, "Amount must be > 0");
        
        uint256 payment = wellAmount * wellBuybackPrice;
        require(address(this).balance >= payment, "Insufficient treasury balance");
        
        // Burn WELL tokens from user
        tokenEngine.burnWELL(wellAmount);
        
        // Send ETH to user
        (bool success, ) = msg.sender.call{value: payment}("");
        require(success, "Payment failed");
        
        emit TokensBoughtBack(msg.sender, wellAmount, payment);
    }
    
    /**
     * @dev Calculate sell value for WELL
     */
    function calculateSellValue(uint256 wellAmount) external view returns (uint256) {
        return wellAmount * wellBuybackPrice;
    }
    
    /**
     * @dev Update revenue split (governance decision)
     */
    function setRevenueSplit(
        uint256 _userBuybacks,
        uint256 _investorRepayment,
        uint256 _operations,
        uint256 _reserve
    ) external onlyRole(ADMIN_ROLE) {
        require(_userBuybacks + _investorRepayment + _operations + _reserve == 100, "Must sum to 100");
        
        split = RevenueSplit({
            userBuybacks: _userBuybacks,
            investorRepayment: _investorRepayment,
            operations: _operations,
            reserve: _reserve
        });
        
        emit SplitUpdated(_userBuybacks, _investorRepayment, _operations, _reserve);
    }
    
    /**
     * @dev Update WELL buyback price
     */
    function setWellBuybackPrice(uint256 newPrice) external onlyRole(ADMIN_ROLE) {
        wellBuybackPrice = newPrice;
    }
    
    /**
     * @dev Toggle buybacks
     */
    function setBuybacksEnabled(bool enabled) external onlyRole(ADMIN_ROLE) {
        buybacksEnabled = enabled;
    }
    
    /**
     * @dev Update treasury addresses
     */
    function setTreasuries(
        address _userBuybackTreasury,
        address _operationsTreasury,
        address _reserveTreasury
    ) external onlyRole(ADMIN_ROLE) {
        require(_userBuybackTreasury != address(0), "Invalid address");
        require(_operationsTreasury != address(0), "Invalid address");
        require(_reserveTreasury != address(0), "Invalid address");
        
        userBuybackTreasury = _userBuybackTreasury;
        operationsTreasury = _operationsTreasury;
        reserveTreasury = _reserveTreasury;
    }
    
    /**
     * @dev Get SEAL investor info
     */
    function getSEALInvestor(address investor) external view returns (SEALInvestor memory) {
        uint256 idx = investorIndex[investor];
        require(idx > 0 || (sealInvestors.length > 0 && sealInvestors[0].investorAddress == investor), "Investor not found");
        return sealInvestors[idx > 0 ? idx - 1 : 0];
    }
    
    /**
     * @dev Get all SEAL investors
     */
    function getAllSEALInvestors() external view returns (SEALInvestor[] memory) {
        return sealInvestors;
    }
    
    /**
     * @dev Check if all investors have reached their caps
     */
    function allCapsReached() external view returns (bool) {
        for (uint i = 0; i < sealInvestors.length; i++) {
            if (!sealInvestors[i].capReached) {
                return false;
            }
        }
        return sealInvestors.length > 0;
    }
    
    /**
     * @dev Emergency withdraw (governance only)
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(to != address(0), "Invalid address");
        (bool success, ) = to.call{value: amount}("");
        require(success, "Withdraw failed");
    }
    
    receive() external payable {
        emit RevenueReceived(msg.value, "direct");
    }
}
