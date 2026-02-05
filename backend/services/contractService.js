/**
 * TerraCare Ledger v2.0 - Contract Service
 * 
 * Handles all smart contract interactions
 */

import { ethers } from 'ethers';
import logger from '../logger.js';

// Contract ABIs (would be imported from artifacts in production)
const TokenEngineABI = [
  "function mineActivity(address to, uint256 valuePoints) external returns (uint256)",
  "function balanceOfMINE(address account) external view returns (uint256)",
  "function balanceOf(address account) external view returns (uint256)",
  "function getTotalMINE(address account) external view returns (uint256)",
  "function getVotingPower(address account) external view returns (uint256)",
  "function stakes(address account) external view returns (uint256 amount, uint256 stakedAt, uint256 lockEnd)",
  "function convertMineToWell(uint256 mineAmount) external",
  "function burnWELL(uint256 amount) external",
  "function purchaseWell(address to, uint256 wellAmount) external",
  "event MineMinted(address indexed to, uint256 amount, uint256 valuePoints)"
];

const ActivityRegistryABI = [
  "function recordActivity(bytes32 activityId, bytes32 userId, uint8 activityType, bytes32 dataHash, uint256 valueScore, address userAddress) external",
  "function getRemainingDailyPoints(bytes32 userId) external view returns (uint256)",
  "function dailyPoints(bytes32) external view returns (uint256)",
  "function activityProofs(bytes32) external view returns (bytes32 userId, uint8 activityType, uint256 timestamp, bytes32 dataHash, uint256 valueScore, address validator, bool rewarded)",
  "function getDailyPoints(bytes32 userId, uint256 day) external view returns (uint256)",
  "event ActivityRecorded(bytes32 indexed activityId, bytes32 indexed userId, uint8 activityType, uint256 valueScore, bytes32 dataHash)"
];

const RevenueDistributorABI = [
  "function distribute() external payable",
  "function sellWell(uint256 wellAmount) external",
  "function wellBuybackPrice() external view returns (uint256)",
  "function addSEALInvestor(address investor, uint256 investmentAmount, uint256 capMultiplier) external",
  "function sealInvestors(uint256) external view returns (address investorAddress, uint256 initialInvestment, uint256 repaymentCap, uint256 paidAmount, bool capReached, uint256 investmentDate)",
  "function totalRevenueReceived() external view returns (uint256)",
  "function totalDistributedToUsers() external view returns (uint256)",
  "function totalDistributedToInvestors() external view returns (uint256)",
  "function totalSEALInvested() external view returns (uint256)",
  "function totalSEALPaid() external view returns (uint256)",
  "function investorIndex(address) external view returns (uint256)"
];

const GovernanceBridgeABI = [
  "function propose(string calldata title, string calldata description, address target, bytes calldata callData) external returns (uint256)",
  "function castVote(uint256 proposalId, bool support) external",
  "function execute(uint256 proposalId) external",
  "function proposals(uint256) external view returns (uint256 id, address proposer, string memory title, string memory description, bytes memory callData, address target, uint256 forVotes, uint256 againstVotes, uint256 startTime, uint256 endTime, bool executed, bool canceled)",
  "function getProposalState(uint256 proposalId) external view returns (string memory)",
  "function getVotes(address account) external view returns (uint256)",
  "function currentPhase() external view returns (uint8)",
  "function validators(uint256) external view returns (address)",
  "function isValidator(address) external view returns (bool)",
  "event ProposalCreated(uint256 indexed id, address indexed proposer, string title, uint256 startTime, uint256 endTime)"
];

const IdentityRegistryABI = [
  "function get(address account) external view returns (uint8 role, bool active, uint256 createdAt, bytes32 userId, bool isCooperativeMember)",
  "function getUserId(address account) external view returns (bytes32)",
  "function getAddressByUserId(bytes32 userId) external view returns (address)",
  "function isCooperativeMember(address account) external view returns (bool)",
  "function getMemberVotingPower(address account) external view returns (uint256)"
];

const AccessControlABI = [
  "function hasAccess(address patient, address caregiver) external view returns (bool)"
];

class ContractService {
  constructor() {
    this.provider = new ethers.JsonRpcProvider(
      process.env.TERRACARE_RPC_URL || 'http://localhost:8545'
    );
    
    // Backend wallet for subsidizing transactions
    this.backendWallet = process.env.BACKEND_PRIVATE_KEY
      ? new ethers.Wallet(process.env.BACKEND_PRIVATE_KEY, this.provider)
      : null;

    // Contract addresses (loaded from environment)
    this.addresses = {
      TokenEngine: process.env.TERRACARE_TOKEN_ENGINE,
      ActivityRegistry: process.env.TERRACARE_ACTIVITY_REGISTRY,
      RevenueDistributor: process.env.TERRACARE_REVENUE_DISTRIBUTOR,
      GovernanceBridge: process.env.TERRACARE_GOVERNANCE_BRIDGE,
      IdentityRegistry: process.env.TERRACARE_IDENTITY_REGISTRY,
      AccessControl: process.env.TERRACARE_ACCESS_CONTROL
    };

    // Initialize contracts
    this.contracts = {};
    this._initializeContracts();
  }

  _initializeContracts() {
    if (this.addresses.TokenEngine) {
      this.contracts.TokenEngine = new ethers.Contract(
        this.addresses.TokenEngine,
        TokenEngineABI,
        this.backendWallet || this.provider
      );
    }

    if (this.addresses.ActivityRegistry) {
      this.contracts.ActivityRegistry = new ethers.Contract(
        this.addresses.ActivityRegistry,
        ActivityRegistryABI,
        this.backendWallet || this.provider
      );
    }

    if (this.addresses.RevenueDistributor) {
      this.contracts.RevenueDistributor = new ethers.Contract(
        this.addresses.RevenueDistributor,
        RevenueDistributorABI,
        this.backendWallet || this.provider
      );
    }

    if (this.addresses.GovernanceBridge) {
      this.contracts.GovernanceBridge = new ethers.Contract(
        this.addresses.GovernanceBridge,
        GovernanceBridgeABI,
        this.backendWallet || this.provider
      );
    }

    if (this.addresses.IdentityRegistry) {
      this.contracts.IdentityRegistry = new ethers.Contract(
        this.addresses.IdentityRegistry,
        IdentityRegistryABI,
        this.provider
      );
    }

    if (this.addresses.AccessControl) {
      this.contracts.AccessControl = new ethers.Contract(
        this.addresses.AccessControl,
        AccessControlABI,
        this.provider
      );
    }
  }

  // ============ Activity Registry Methods ============

  async recordActivity({ activityId, userId, activityType, dataHash, valueScore, userAddress }) {
    if (!this.contracts.ActivityRegistry) {
      throw new Error('ActivityRegistry not initialized');
    }

    // Backend subsidizes gas - calls directly
    const tx = await this.contracts.ActivityRegistry.recordActivity(
      activityId,
      ethers.encodeBytes32String(userId),
      activityType,
      dataHash,
      valueScore,
      userAddress,
      { gasPrice: 0 } // PoA network
    );

    return tx;
  }

  async getRemainingDailyPoints(userId) {
    if (!this.contracts.ActivityRegistry) return 100;
    
    try {
      const points = await this.contracts.ActivityRegistry.getRemainingDailyPoints(
        ethers.encodeBytes32String(userId)
      );
      return Number(points);
    } catch (error) {
      logger.error({ error: error.message }, 'Error getting remaining daily points');
      return 100; // Default to full cap on error
    }
  }

  async getUsedDailyPoints(userId) {
    if (!this.contracts.ActivityRegistry) return 0;

    try {
      const day = Math.floor(Date.now() / 1000 / 86400);
      const dailyKey = ethers.keccak256(
        ethers.solidityPacked(['bytes32', 'uint256'], [ethers.encodeBytes32String(userId), day])
      );
      const points = await this.contracts.ActivityRegistry.dailyPoints(dailyKey);
      return Number(points);
    } catch (error) {
      return 0;
    }
  }

  async getSecondsUntilNextDay(userId) {
    const now = Math.floor(Date.now() / 1000);
    const nextDay = Math.ceil(now / 86400) * 86400;
    return nextDay - now;
  }

  // ============ Token Engine Methods ============

  async getMineBalance(address) {
    if (!this.contracts.TokenEngine) return 0n;
    return await this.contracts.TokenEngine.getTotalMINE(address);
  }

  async getWellBalance(address) {
    if (!this.contracts.TokenEngine) return 0n;
    return await this.contracts.TokenEngine.balanceOf(address);
  }

  async getStakedMine(address) {
    if (!this.contracts.TokenEngine) return 0n;
    const stake = await this.contracts.TokenEngine.stakes(address);
    return stake.amount;
  }

  async getVotingPower(address) {
    if (!this.contracts.TokenEngine) return 0n;
    return await this.contracts.TokenEngine.getVotingPower(address);
  }

  async convertMineToWell(address, mineAmount) {
    if (!this.contracts.TokenEngine) throw new Error('TokenEngine not initialized');
    
    const tx = await this.contracts.TokenEngine.convertMineToWell(mineAmount, {
      from: address,
      gasPrice: 0
    });
    return tx;
  }

  // ============ Identity Registry Methods ============

  async getUserAddress(userId) {
    if (!this.contracts.IdentityRegistry) return null;
    
    try {
      return await this.contracts.IdentityRegistry.getAddressByUserId(
        ethers.encodeBytes32String(userId)
      );
    } catch (error) {
      return null;
    }
  }

  async isCooperativeMember(address) {
    if (!this.contracts.IdentityRegistry) return false;
    return await this.contracts.IdentityRegistry.isCooperativeMember(address);
  }

  async validateDeviceSignature(deviceId, userId, data, signature) {
    // In production: verify against registered devices in contract
    // For now, simulate validation
    try {
      const message = ethers.keccak256(
        ethers.solidityPacked(
          ['string', 'bytes32', 'bytes'],
          [deviceId, ethers.encodeBytes32String(userId), ethers.toUtf8Bytes(JSON.stringify(data))]
        )
      );
      const recovered = ethers.verifyMessage(ethers.getBytes(message), signature);
      return recovered !== ethers.ZeroAddress;
    } catch (error) {
      return false;
    }
  }

  // ============ Access Control Methods ============

  async checkAccess(patientAddress, caregiverAddress) {
    if (!this.contracts.AccessControl) return false;
    return await this.contracts.AccessControl.hasAccess(patientAddress, caregiverAddress);
  }

  // ============ Revenue Distributor Methods ============

  async distributeRevenue({ value, source, paymentId }) {
    if (!this.contracts.RevenueDistributor) {
      throw new Error('RevenueDistributor not initialized');
    }

    const tx = await this.contracts.RevenueDistributor.distribute({
      value,
      gasPrice: 0
    });

    return tx;
  }

  async getRevenueStats() {
    if (!this.contracts.RevenueDistributor) {
      return {
        totalRevenue: 0n,
        totalToUsers: 0n,
        totalToInvestors: 0n,
        totalToOperations: 0n,
        totalToReserve: 0n,
        totalSEALInvested: 0n,
        totalSEALPaid: 0n,
        investors: []
      };
    }

    const [
      totalRevenue,
      totalToUsers,
      totalToInvestors,
      totalToOperations,
      totalToReserve,
      totalSEALInvested,
      totalSEALPaid
    ] = await Promise.all([
      this.contracts.RevenueDistributor.totalRevenueReceived(),
      this.contracts.RevenueDistributor.totalDistributedToUsers(),
      this.contracts.RevenueDistributor.totalDistributedToInvestors(),
      this.contracts.RevenueDistributor.totalDistributedToOperations(),
      this.contracts.RevenueDistributor.totalDistributedToReserve(),
      this.contracts.RevenueDistributor.totalSEALInvested(),
      this.contracts.RevenueDistributor.totalSEALPaid()
    ]);

    // Get all investors
    const investors = [];
    let idx = 0;
    while (true) {
      try {
        const investor = await this.contracts.RevenueDistributor.sealInvestors(idx);
        if (investor.investorAddress === ethers.ZeroAddress) break;
        investors.push(investor);
        idx++;
      } catch (error) {
        break;
      }
    }

    return {
      totalRevenue,
      totalToUsers,
      totalToInvestors,
      totalToOperations,
      totalToReserve,
      totalSEALInvested,
      totalSEALPaid,
      investors
    };
  }

  async getSEALInvestor(address) {
    if (!this.contracts.RevenueDistributor) return null;

    try {
      const idx = await this.contracts.RevenueDistributor.investorIndex(address);
      if (idx === 0n) return null;
      
      return await this.contracts.RevenueDistributor.sealInvestors(idx - 1n);
    } catch (error) {
      return null;
    }
  }

  async getWellBuybackPrice() {
    if (!this.contracts.RevenueDistributor) return 0n;
    return await this.contracts.RevenueDistributor.wellBuybackPrice();
  }

  async sellWell({ from, amount }) {
    if (!this.contracts.RevenueDistributor) {
      throw new Error('RevenueDistributor not initialized');
    }

    const tx = await this.contracts.RevenueDistributor.sellWell(amount, {
      from,
      gasPrice: 0
    });

    return tx;
  }

  async getETHPriceInUSD() {
    // In production: Use Chainlink oracle or similar
    // For now, return mock price
    return 2000; // $2000 per ETH
  }

  async convertETHtoUSD(ethAmount) {
    const price = await this.getETHPriceInUSD();
    const eth = Number(ethers.formatEther(ethAmount));
    return eth * price;
  }

  // ============ Governance Methods ============

  async createProposal({ proposer, title, description, target, callData }) {
    if (!this.contracts.GovernanceBridge) {
      throw new Error('GovernanceBridge not initialized');
    }

    const tx = await this.contracts.GovernanceBridge.propose(
      title,
      description,
      target,
      callData,
      { from: proposer, gasPrice: 0 }
    );

    return tx;
  }

  async castVote({ voter, proposalId, support }) {
    if (!this.contracts.GovernanceBridge) {
      throw new Error('GovernanceBridge not initialized');
    }

    const tx = await this.contracts.GovernanceBridge.castVote(proposalId, support, {
      from: voter,
      gasPrice: 0
    });

    return tx;
  }

  async executeProposal(proposalId) {
    if (!this.contracts.GovernanceBridge) {
      throw new Error('GovernanceBridge not initialized');
    }

    const tx = await this.contracts.GovernanceBridge.execute(proposalId, { gasPrice: 0 });
    return tx;
  }

  async getProposalState(proposalId) {
    if (!this.contracts.GovernanceBridge) return 'Unknown';
    return await this.contracts.GovernanceBridge.getProposalState(proposalId);
  }

  async getProposal(proposalId) {
    if (!this.contracts.GovernanceBridge) return null;
    
    const proposal = await this.contracts.GovernanceBridge.proposals(proposalId);
    const state = await this.getProposalState(proposalId);
    
    return {
      ...proposal,
      state
    };
  }

  async getProposals({ page, limit, state }) {
    // In production: query events for all proposals
    // For now, return mock data
    return { items: [], total: 0 };
  }

  async hasVoted(proposalId, voter) {
    if (!this.contracts.GovernanceBridge) return false;
    // Would check proposal.voters mapping
    return false;
  }

  async getGovernancePhase() {
    if (!this.contracts.GovernanceBridge) return 'PoA';
    
    const phase = await this.contracts.GovernanceBridge.currentPhase();
    const phases = ['PoA', 'Transition', 'Cooperative'];
    return phases[phase] || 'Unknown';
  }

  async getTimeUntilNextPhase() {
    // Would calculate based on deployment timestamp
    return 0;
  }

  async isValidator(address) {
    if (!this.contracts.GovernanceBridge) return false;
    return await this.contracts.GovernanceBridge.isValidator(address);
  }

  async getValidators() {
    if (!this.contracts.GovernanceBridge) return [];
    
    const validators = [];
    let idx = 0;
    while (true) {
      try {
        const validator = await this.contracts.GovernanceBridge.validators(idx);
        if (validator === ethers.ZeroAddress) break;
        validators.push(validator);
        idx++;
      } catch (error) {
        break;
      }
    }
    return validators;
  }

  async delegate({ delegator, delegatee }) {
    if (!this.contracts.GovernanceBridge) {
      throw new Error('GovernanceBridge not initialized');
    }

    // Note: delegation is done through TokenEngine staking
    return { hash: '0x0' };
  }

  async getDelegate(address) {
    if (!this.contracts.GovernanceBridge) return ethers.ZeroAddress;
    // Would query delegates mapping
    return ethers.ZeroAddress;
  }

  async getDelegatedPower(address) {
    if (!this.contracts.GovernanceBridge) return 0n;
    // Would query delegatedVotes mapping
    return 0n;
  }

  // ============ User Activity Methods ============

  async getUserActivities(userId, page, limit) {
    // In production: query ActivityRecorded events
    return { items: [], total: 0 };
  }
}

export default ContractService;
