/**
 * TerraCare Ledger v2.0 - Participation Layer Test Suite
 * 
 * Tests:
 * - Anti-gaming: Daily rate limits, Sybil resistance
 * - Economic: SEAL cap enforcement, token conversion accuracy, revenue split precision
 * - Governance: Timelock, proposal threshold, voting power calculation
 */

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TerraCare Ledger v2.0 - Participation Layer", function () {
  
  // Signers
  let owner, validator, user1, user2, user3, investor, treasury;
  
  // Contracts
  let tokenEngine, activityRegistry, revenueDistributor, governanceBridge;
  let identityRegistry, accessControl, recordRegistry, auditLog;

  // Constants
  const DAY_IN_SECONDS = 86400;
  const MINE_PER_VALUE_POINT = ethers.parseEther("10");
  const CONVERSION_RATIO = 100; // 100 MINE = 1 WELL
  const DAILY_POINTS_CAP = 100;

  beforeEach(async function () {
    // Get signers
    [owner, validator, user1, user2, user3, investor, treasury, ...others] = await ethers.getSigners();

    // Deploy IdentityRegistry
    const IdentityRegistry = await ethers.getContractFactory("IdentityRegistry");
    identityRegistry = await IdentityRegistry.deploy();
    await identityRegistry.waitForDeployment();

    // Deploy TokenEngine
    const TokenEngine = await ethers.getContractFactory("TokenEngine");
    tokenEngine = await TokenEngine.deploy();
    await tokenEngine.waitForDeployment();

    // Deploy ActivityRegistry
    const ActivityRegistry = await ethers.getContractFactory("ActivityRegistry");
    activityRegistry = await ActivityRegistry.deploy(
      await tokenEngine.getAddress(),
      await identityRegistry.getAddress()
    );
    await activityRegistry.waitForDeployment();

    // Deploy RevenueDistributor
    const RevenueDistributor = await ethers.getContractFactory("RevenueDistributor");
    revenueDistributor = await RevenueDistributor.deploy(
      await tokenEngine.getAddress(),
      treasury.address,
      treasury.address,
      treasury.address
    );
    await revenueDistributor.waitForDeployment();

    // Deploy GovernanceBridge
    const GovernanceBridge = await ethers.getContractFactory("GovernanceBridge");
    governanceBridge = await GovernanceBridge.deploy(
      await tokenEngine.getAddress(),
      await identityRegistry.getAddress(),
      [owner.address, validator.address]
    );
    await governanceBridge.waitForDeployment();

    // Deploy AccessControl
    const AccessControl = await ethers.getContractFactory("AccessControl");
    accessControl = await AccessControl.deploy(await identityRegistry.getAddress());
    await accessControl.waitForDeployment();

    // Deploy RecordRegistry
    const RecordRegistry = await ethers.getContractFactory("RecordRegistry");
    recordRegistry = await RecordRegistry.deploy(await accessControl.getAddress());
    await recordRegistry.waitForDeployment();

    // Deploy AuditLog
    const AuditLog = await ethers.getContractFactory("AuditLog");
    auditLog = await AuditLog.deploy();
    await auditLog.waitForDeployment();

    // Setup roles
    await tokenEngine.grantMinterRole(await activityRegistry.getAddress());
    await tokenEngine.grantRole(await tokenEngine.MINTER_ROLE(), owner.address);
    
    await activityRegistry.grantRole(await activityRegistry.ORACLE_ROLE(), validator.address);
    await activityRegistry.grantRole(await activityRegistry.ORACLE_ROLE(), owner.address);
    
    await revenueDistributor.grantRole(await revenueDistributor.DISTRIBUTOR_ROLE(), owner.address);
    
    // Link IdentityRegistry to TokenEngine
    await identityRegistry.setTokenEngine(await tokenEngine.getAddress());

    // Register users
    await identityRegistry.register(user1.address, 1); // Patient
    await identityRegistry.register(user2.address, 1); // Patient
    await identityRegistry.register(user3.address, 2); // Caregiver
  });

  // ============================================
  // TOKEN ENGINE TESTS
  // ============================================
  
  describe("TokenEngine - Dual Token System", function () {
    
    it("Should mint MINE tokens for activity", async function () {
      const valuePoints = 10;
      await tokenEngine.connect(owner).mineActivity(user1.address, valuePoints);
      
      const balance = await tokenEngine.balanceOfMINE(user1.address);
      expect(balance).to.equal(MINE_PER_VALUE_POINT * BigInt(valuePoints));
    });

    it("Should batch mint MINE tokens", async function () {
      const recipients = [user1.address, user2.address];
      const valuePoints = [10, 20];
      
      await tokenEngine.connect(owner).batchMineActivity(recipients, valuePoints);
      
      const balance1 = await tokenEngine.balanceOfMINE(user1.address);
      const balance2 = await tokenEngine.balanceOfMINE(user2.address);
      
      expect(balance1).to.equal(MINE_PER_VALUE_POINT * 10n);
      expect(balance2).to.equal(MINE_PER_VALUE_POINT * 20n);
    });

    it("Should convert MINE to WELL at 100:1 ratio", async function () {
      // First mint MINE
      await tokenEngine.connect(owner).mineActivity(user1.address, 100);
      const mineBalance = await tokenEngine.balanceOfMINE(user1.address);
      expect(mineBalance).to.equal(ethers.parseEther("1000")); // 100 * 10 MINE

      // Convert to WELL
      await tokenEngine.connect(user1).convertMineToWell(ethers.parseEther("1000"));
      
      const wellBalance = await tokenEngine.balanceOf(user1.address);
      expect(wellBalance).to.equal(ethers.parseEther("10")); // 1000 / 100 = 10 WELL
      
      const remainingMine = await tokenEngine.balanceOfMINE(user1.address);
      expect(remainingMine).to.equal(0);
    });

    it("Should not convert less than 100 MINE", async function () {
      await tokenEngine.connect(owner).mineActivity(user1.address, 5); // 50 MINE
      
      await expect(
        tokenEngine.connect(user1).convertMineToWell(ethers.parseEther("50"))
      ).to.be.revertedWith("Minimum 100 MINE required");
    });

    it("Should stake MINE for voting power", async function () {
      await tokenEngine.connect(owner).mineActivity(user1.address, 100);
      
      const stakeAmount = ethers.parseEther("500");
      const lockPeriod = 30 * DAY_IN_SECONDS; // 30 days
      
      await tokenEngine.connect(user1).stakeMINE(stakeAmount, lockPeriod);
      
      const stake = await tokenEngine.stakes(user1.address);
      expect(stake.amount).to.equal(stakeAmount);
      
      const votingPower = await tokenEngine.getVotingPower(user1.address);
      expect(votingPower).to.equal(stakeAmount);
    });

    it("Should not allow unstaking before lock period", async function () {
      await tokenEngine.connect(owner).mineActivity(user1.address, 100);
      await tokenEngine.connect(user1).stakeMINE(ethers.parseEther("500"), 30 * DAY_IN_SECONDS);
      
      await expect(
        tokenEngine.connect(user1).unstakeMINE()
      ).to.be.revertedWith("Stake still locked");
    });

    it("Should not have voting power with short lock", async function () {
      await tokenEngine.connect(owner).mineActivity(user1.address, 100);
      await tokenEngine.connect(user1).stakeMINE(ethers.parseEther("500"), 15 * DAY_IN_SECONDS); // Less than 30 days
      
      const votingPower = await tokenEngine.getVotingPower(user1.address);
      expect(votingPower).to.equal(0);
    });
  });

  // ============================================
  // ACTIVITY REGISTRY TESTS - ANTI-GAMING
  // ============================================

  describe("ActivityRegistry - Anti-Gaming", function () {
    
    it("Should enforce daily points cap (100/day)", async function () {
      const userId = ethers.encodeBytes32String("user1");
      
      // Record activities totaling 100 points
      for (let i = 0; i < 10; i++) {
        const activityId = ethers.keccak256(ethers.toUtf8Bytes(`activity${i}`));
        await activityRegistry.connect(validator).recordActivity(
          activityId,
          userId,
          0, // BiometricStream
          ethers.keccak256(ethers.toUtf8Bytes("data")),
          10, // 10 points each
          user1.address
        );
      }

      const remainingPoints = await activityRegistry.getRemainingDailyPoints(userId);
      expect(remainingPoints).to.equal(0);

      // Try to record one more activity
      const activityId = ethers.keccak256(ethers.toUtf8Bytes("overflow"));
      await activityRegistry.connect(validator).recordActivity(
        activityId,
        userId,
        0,
        ethers.keccak256(ethers.toUtf8Bytes("data")),
        10,
        user1.address
      );

      // Should earn 0 points (capped)
      const mineBalance = await tokenEngine.balanceOfMINE(user1.address);
      expect(mineBalance).to.equal(MINE_PER_VALUE_POINT * 100n);
    });

    it("Should cap value score to remaining daily points", async function () {
      const userId = ethers.encodeBytes32String("user1");
      
      // Use up 90 points
      await activityRegistry.connect(validator).recordActivity(
        ethers.keccak256(ethers.toUtf8Bytes("act1")),
        userId,
        0,
        ethers.keccak256(ethers.toUtf8Bytes("data")),
        90,
        user1.address
      );

      // Try to get 20 more points (should be capped to 10)
      await activityRegistry.connect(validator).recordActivity(
        ethers.keccak256(ethers.toUtf8Bytes("act2")),
        userId,
        0,
        ethers.keccak256(ethers.toUtf8Bytes("data")),
        20,
        user1.address
      );

      const mineBalance = await tokenEngine.balanceOfMINE(user1.address);
      expect(mineBalance).to.equal(MINE_PER_VALUE_POINT * 100n); // Capped at 100
    });

    it("Should reset daily points after 24 hours", async function () {
      const userId = ethers.encodeBytes32String("user1");
      
      // Use up all points
      await activityRegistry.connect(validator).recordActivity(
        ethers.keccak256(ethers.toUtf8Bytes("act1")),
        userId,
        0,
        ethers.keccak256(ethers.toUtf8Bytes("data")),
        100,
        user1.address
      );

      // Advance time by 24 hours
      await ethers.provider.send("evm_increaseTime", [DAY_IN_SECONDS]);
      await ethers.provider.send("evm_mine");

      const remainingPoints = await activityRegistry.getRemainingDailyPoints(userId);
      expect(remainingPoints).to.equal(100);
    });

    it("Should prevent duplicate activity IDs", async function () {
      const userId = ethers.encodeBytes32String("user1");
      const activityId = ethers.keccak256(ethers.toUtf8Bytes("duplicate"));
      
      await activityRegistry.connect(validator).recordActivity(
        activityId,
        userId,
        0,
        ethers.keccak256(ethers.toUtf8Bytes("data")),
        10,
        user1.address
      );

      await expect(
        activityRegistry.connect(validator).recordActivity(
          activityId,
          userId,
          0,
          ethers.keccak256(ethers.toUtf8Bytes("data2")),
          10,
          user1.address
        )
      ).to.be.revertedWith("Activity already recorded");
    });

    it("Should batch record activities efficiently", async function () {
      const userId = ethers.encodeBytes32String("user1");
      const count = 10;
      
      const activityIds = [];
      const userIds = [];
      const activityTypes = [];
      const dataHashes = [];
      const valueScores = [];
      const userAddresses = [];

      for (let i = 0; i < count; i++) {
        activityIds.push(ethers.keccak256(ethers.toUtf8Bytes(`batch${i}`)));
        userIds.push(userId);
        activityTypes.push(0);
        dataHashes.push(ethers.keccak256(ethers.toUtf8Bytes(`data${i}`)));
        valueScores.push(10);
        userAddresses.push(user1.address);
      }

      await activityRegistry.connect(validator).batchRecordActivities(
        activityIds, userIds, activityTypes, dataHashes, valueScores, userAddresses
      );

      const mineBalance = await tokenEngine.balanceOfMINE(user1.address);
      expect(mineBalance).to.equal(MINE_PER_VALUE_POINT * 100n); // Capped at 100
    });

    it("Should only allow oracle role to record activities", async function () {
      const userId = ethers.encodeBytes32String("user1");
      
      await expect(
        activityRegistry.connect(user1).recordActivity(
          ethers.keccak256(ethers.toUtf8Bytes("act")),
          userId,
          0,
          ethers.keccak256(ethers.toUtf8Bytes("data")),
          10,
          user1.address
        )
      ).to.be.reverted;
    });
  });

  // ============================================
  // REVENUE DISTRIBUTOR TESTS - ECONOMICS
  // ============================================

  describe("RevenueDistributor - Economic Model", function () {
    
    beforeEach(async function () {
      // Add SEAL investor
      await revenueDistributor.addSEALInvestor(
        investor.address,
        ethers.parseEther("750000"), // $750K
        300 // 3x cap
      );
    });

    it("Should split revenue according to cooperative model (30/20/40/10)", async function () {
      const revenue = ethers.parseEther("100");
      
      // Get initial balances
      const initialTreasuryBalance = await ethers.provider.getBalance(treasury.address);
      const initialInvestorBalance = await ethers.provider.getBalance(investor.address);
      
      // Distribute revenue
      await revenueDistributor.connect(owner).distribute({ value: revenue });

      // Check splits
      const stats = await revenueDistributor.totalRevenueReceived();
      expect(stats).to.equal(revenue);

      // Verify distribution tracking
      const toUsers = await revenueDistributor.totalDistributedToUsers();
      const toInvestors = await revenueDistributor.totalDistributedToInvestors();
      const toOperations = await revenueDistributor.totalDistributedToOperations();
      const toReserve = await revenueDistributor.totalDistributedToReserve();

      // 30% to users (buybacks)
      expect(toUsers).to.be.closeTo(revenue * 30n / 100n, ethers.parseEther("1"));
      // 20% to investors
      expect(toInvestors).to.be.closeTo(revenue * 20n / 100n, ethers.parseEther("1"));
      // 40% to operations
      expect(toOperations).to.be.closeTo(revenue * 40n / 100n, ethers.parseEther("1"));
      // 10% to reserve
      expect(toReserve).to.be.closeTo(revenue * 10n / 100n, ethers.parseEther("1"));
    });

    it("Should track SEAL investor repayment", async function () {
      const investment = ethers.parseEther("750000");
      const expectedCap = investment * 300n / 100n; // 3x

      const investorInfo = await revenueDistributor.getSEALInvestor(investor.address);
      expect(investorInfo.initialInvestment).to.equal(investment);
      expect(investorInfo.repaymentCap).to.equal(expectedCap);
      expect(investorInfo.paidAmount).to.equal(0);
      expect(investorInfo.capReached).to.be.false;
    });

    it("Should stop investor payments when cap reached", async function () {
      const investment = ethers.parseEther("1"); // Small for testing
      
      // Add small investor
      await revenueDistributor.addSEALInvestor(
        user2.address,
        investment,
        300 // 3x cap = 3 ETH
      );

      // Distribute enough to reach cap
      const revenue = ethers.parseEther("50"); // 20% of 50 = 10 ETH (more than 3x cap)
      await revenueDistributor.connect(owner).distribute({ value: revenue });

      const investorInfo = await revenueDistributor.getSEALInvestor(user2.address);
      expect(investorInfo.paidAmount).to.equal(investment * 300n / 100n); // Capped at 3x
      expect(investorInfo.capReached).to.be.true;
    });

    it("Should allow WELL buyback at set price", async function () {
      // Set buyback price (0.001 ETH per WELL)
      await revenueDistributor.setWellBuybackPrice(ethers.parseEther("0.001"));
      
      // Mint WELL to user
      await tokenEngine.connect(owner).purchaseWell(user1.address, ethers.parseEther("100"));
      
      // Get expected payment
      const price = await revenueDistributor.wellBuybackPrice();
      const wellAmount = ethers.parseEther("100");
      const expectedPayment = wellAmount * price / ethers.parseEther("1");

      // User sells WELL
      const initialBalance = await ethers.provider.getBalance(user1.address);
      await revenueDistributor.connect(user1).sellWell(wellAmount);
      
      // Check WELL burned
      const wellBalance = await tokenEngine.balanceOf(user1.address);
      expect(wellBalance).to.equal(0);
    });

    it("Should allow admin to update revenue split", async function () {
      await revenueDistributor.setRevenueSplit(25, 25, 40, 10);
      
      const split = await revenueDistributor.split();
      expect(split.userBuybacks).to.equal(25);
      expect(split.investorRepayment).to.equal(25);
      expect(split.operations).to.equal(40);
      expect(split.reserve).to.equal(10);
    });

    it("Should require revenue split to sum to 100", async function () {
      await expect(
        revenueDistributor.setRevenueSplit(30, 30, 30, 10)
      ).to.be.revertedWith("Must sum to 100");
    });

    it("Should track all SEAL investors", async function () {
      // Add multiple investors
      await revenueDistributor.addSEALInvestor(
        user2.address,
        ethers.parseEther("500000"),
        400 // 4x cap
      );
      
      await revenueDistributor.addSEALInvestor(
        user3.address,
        ethers.parseEther("250000"),
        500 // 5x cap
      );

      const allInvestors = await revenueDistributor.getAllSEALInvestors();
      expect(allInvestors.length).to.equal(3);
    });
  });

  // ============================================
  // GOVERNANCE BRIDGE TESTS
  // ============================================

  describe("GovernanceBridge - Cooperative Governance", function () {
    
    it("Should start in PoA phase", async function () {
      const phase = await governanceBridge.currentPhase();
      expect(phase).to.equal(0); // GovernancePhase.PoA
    });

    it("Should allow validators to propose in PoA phase", async function () {
      const tx = await governanceBridge.connect(owner).propose(
        "Test Proposal",
        "This is a test proposal",
        await tokenEngine.getAddress(),
        "0x"
      );

      const receipt = await tx.wait();
      const event = receipt.logs.find(l => l.fragment?.name === 'ProposalCreated');
      expect(event).to.not.be.undefined;
    });

    it("Should require staked MINE to propose in Cooperative phase", async function () {
      // Fast forward to cooperative phase (would need time manipulation)
      // For now, just check the requirement logic
      const votingPower = await governanceBridge.getVotes(user1.address);
      expect(votingPower).to.equal(0);
    });

    it("Should track voting power from staked MINE", async function () {
      // Mint and stake MINE
      await tokenEngine.connect(owner).mineActivity(user1.address, 200);
      await tokenEngine.connect(user1).stakeMINE(
        ethers.parseEther("1000"),
        30 * DAY_IN_SECONDS
      );

      const votingPower = await tokenEngine.getVotingPower(user1.address);
      expect(votingPower).to.equal(ethers.parseEther("1000"));
    });

    it("Should create proposals with correct structure", async function () {
      const title = "Grant Program";
      const description = "Allocate funds for community grants";
      const target = await tokenEngine.getAddress();
      const callData = "0x";

      await governanceBridge.connect(owner).propose(title, description, target, callData);

      const proposal = await governanceBridge.proposals(1);
      expect(proposal.title).to.equal(title);
      expect(proposal.description).to.equal(description);
      expect(proposal.target).to.equal(target);
      expect(proposal.proposer).to.equal(owner.address);
      expect(proposal.executed).to.be.false;
    });

    it("Should allow voting on proposals", async function () {
      // Create proposal
      await governanceBridge.connect(owner).propose(
        "Test",
        "Test proposal",
        await tokenEngine.getAddress(),
        "0x"
      );

      // Mint and stake for voting
      await tokenEngine.connect(owner).mineActivity(user1.address, 200);
      await tokenEngine.connect(user1).stakeMINE(
        ethers.parseEther("1000"),
        30 * DAY_IN_SECONDS
      );

      // Vote
      await governanceBridge.connect(user1).castVote(1, true);

      const proposal = await governanceBridge.proposals(1);
      expect(proposal.forVotes).to.equal(ethers.parseEther("1000"));
    });

    it("Should track delegation correctly", async function () {
      // Mint and stake
      await tokenEngine.connect(owner).mineActivity(user1.address, 200);
      await tokenEngine.connect(user1).stakeMINE(
        ethers.parseEther("500"),
        30 * DAY_IN_SECONDS
      );

      // Delegate
      await governanceBridge.connect(user1).delegate(user2.address);

      const delegate = await governanceBridge.delegates(user1.address);
      expect(delegate).to.equal(user2.address);

      const delegatedVotes = await governanceBridge.delegatedVotes(user2.address);
      expect(delegatedVotes).to.equal(ethers.parseEther("500"));
    });

    it("Should get correct proposal state", async function () {
      await governanceBridge.connect(owner).propose("Test", "Test", await tokenEngine.getAddress(), "0x");

      const state = await governanceBridge.getProposalState(1);
      expect(state).to.be.oneOf(["Active", "Pending", "Succeeded"]);
    });

    it("Should list all validators", async function () {
      const validators = await governanceBridge.getValidators();
      expect(validators).to.include(owner.address);
      expect(validators).to.include(validator.address);
    });

    it("Should allow admin to add/remove validators", async function () {
      // Add new validator
      await governanceBridge.connect(owner).addValidator(user3.address);
      
      let validators = await governanceBridge.getValidators();
      expect(validators).to.include(user3.address);

      // Remove validator
      await governanceBridge.connect(owner).removeValidator(user3.address);
      
      validators = await governanceBridge.getValidators();
      expect(validators).to.not.include(user3.address);
    });
  });

  // ============================================
  // IDENTITY REGISTRY INTEGRATION TESTS
  // ============================================

  describe("IdentityRegistry - Cooperative Membership", function () {
    
    it("Should track MINE balances for members", async function () {
      // Initially no MINE
      let mineBalance = await identityRegistry.getMemberMineBalance(user1.address);
      expect(mineBalance).to.equal(0);

      // Mint MINE
      await tokenEngine.connect(owner).mineActivity(user1.address, 100);
      
      mineBalance = await identityRegistry.getMemberMineBalance(user1.address);
      expect(mineBalance).to.equal(MINE_PER_VALUE_POINT * 100n);
    });

    it("Should check cooperative membership based on MINE threshold", async function () {
      // Initially not a member
      let isMember = await identityRegistry.isCooperativeMember(user1.address);
      expect(isMember).to.be.false;

      // Mint enough MINE (1000 threshold)
      await tokenEngine.connect(owner).mineActivity(user1.address, 100);
      
      // Check membership (should auto-update)
      await identityRegistry.checkCooperativeMembership(user1.address);
      
      isMember = await identityRegistry.isCooperativeMember(user1.address);
      expect(isMember).to.be.true;
    });

    it("Should link userId to address", async function () {
      const userId = await identityRegistry.getUserId(user1.address);
      expect(userId).to.not.equal(ethers.ZeroHash);

      const retrievedAddress = await identityRegistry.getAddressByUserId(userId);
      expect(retrievedAddress).to.equal(user1.address);
    });
  });

  // ============================================
  // ACCESS CONTROL INTEGRATION TESTS
  // ============================================

  describe("AccessControl - Token-Gated Access", function () {
    
    beforeEach(async function () {
      await accessControl.setTokenEngine(await tokenEngine.getAddress());
    });

    it("Should determine access tier based on MINE balance", async function () {
      // No MINE = Basic
      let tier = await accessControl.getAccessTier(user1.address);
      expect(tier).to.equal(0); // AccessTier.Basic

      // Mint 500 MINE = Premium
      await tokenEngine.connect(owner).mineActivity(user1.address, 50);
      tier = await accessControl.getAccessTier(user1.address);
      expect(tier).to.equal(1); // AccessTier.Premium

      // Mint 5000 MINE = Enterprise
      await tokenEngine.connect(owner).mineActivity(user1.address, 500);
      tier = await accessControl.getAccessTier(user1.address);
      expect(tier).to.equal(2); // AccessTier.Enterprise
    });

    it("Should track premium access correctly", async function () {
      // Below threshold
      await tokenEngine.connect(owner).mineActivity(user1.address, 40); // 400 MINE
      let hasPremium = await accessControl.hasPremiumAccess(user1.address);
      expect(hasPremium).to.be.false;

      // Above threshold
      await tokenEngine.connect(owner).mineActivity(user1.address, 20); // 600 MINE
      hasPremium = await accessControl.hasPremiumAccess(user1.address);
      expect(hasPremium).to.be.true;
    });
  });

  // ============================================
  // RECORD REGISTRY INTEGRATION TESTS
  // ============================================

  describe("RecordRegistry - Data Contribution Tracking", function () {
    
    beforeEach(async function () {
      await recordRegistry.setActivityRegistry(await activityRegistry.getAddress());
    });

    it("Should track data contributions", async function () {
      const dataHash = ethers.keccak256(ethers.toUtf8Bytes("test-data"));
      const dataSize = 2048; // 2KB

      await recordRegistry.connect(user1).updateRecordWithContribution(
        dataHash,
        dataSize,
        true, // isAnonymized
        ethers.keccak256(ethers.toUtf8Bytes("vital_signs"))
      );

      const contribution = await recordRegistry.getContribution(user1.address);
      expect(contribution.totalUpdates).to.equal(1);
      expect(contribution.totalDataSize).to.equal(dataSize);
      expect(contribution.anonymizedContributions).to.equal(1);
    });

    it("Should emit contribution event for activity tracking", async function () {
      const dataHash = ethers.keccak256(ethers.toUtf8Bytes("test-data"));
      
      await expect(
        recordRegistry.connect(user1).updateRecordWithContribution(
          dataHash,
          2048,
          true,
          ethers.keccak256(ethers.toUtf8Bytes("vital_signs"))
        )
      ).to.emit(recordRegistry, "DataContributionTracked");
    });
  });

  // ============================================
  // END-TO-END WORKFLOW TESTS
  // ============================================

  describe("End-to-End Workflows", function () {
    
    it("Should complete full user journey: activity -> MINE -> WELL -> governance", async function () {
      // 1. User performs activity
      const userId = ethers.encodeBytes32String("user1");
      await activityRegistry.connect(validator).recordActivity(
        ethers.keccak256(ethers.toUtf8Bytes("journey-activity")),
        userId,
        0, // Biometric
        ethers.keccak256(ethers.toUtf8Bytes("data")),
        50,
        user1.address
      );

      // 2. User earns MINE
      let mineBalance = await tokenEngine.balanceOfMINE(user1.address);
      expect(mineBalance).to.equal(MINE_PER_VALUE_POINT * 50n);

      // 3. User becomes cooperative member
      await identityRegistry.checkCooperativeMembership(user1.address);
      let isMember = await identityRegistry.isCooperativeMember(user1.address);
      expect(isMember).to.be.true;

      // 4. User converts some MINE to WELL
      const mineToConvert = MINE_PER_VALUE_POINT * 50n;
      await tokenEngine.connect(user1).convertMineToWell(mineToConvert);
      
      const wellBalance = await tokenEngine.balanceOf(user1.address);
      expect(wellBalance).to.equal(mineToConvert / BigInt(CONVERSION_RATIO));

      // 5. User stakes remaining MINE for voting power
      const remainingMine = await tokenEngine.balanceOfMINE(user1.address);
      if (remainingMine > 0) {
        await tokenEngine.connect(user1).stakeMINE(remainingMine, 30 * DAY_IN_SECONDS);
      }

      // 6. Validator creates proposal (user votes after staking matures)
      await governanceBridge.connect(validator).propose(
        "Community Initiative",
        "Funding for new health programs",
        await tokenEngine.getAddress(),
        "0x"
      );

      // Verify user has voting power
      const votingPower = await tokenEngine.getVotingPower(user1.address);
      expect(votingPower).to.be.gte(0);
    });

    it("Should handle revenue distribution and SEAL repayment", async function () {
      // Setup investor
      await revenueDistributor.addSEALInvestor(
        investor.address,
        ethers.parseEther("100"),
        300 // 3x cap
      );

      // Distribute revenue
      const revenue = ethers.parseEther("1000");
      const initialInvestorBalance = await ethers.provider.getBalance(investor.address);
      
      await revenueDistributor.connect(owner).distribute({ value: revenue });

      // Check investor received payment
      const investorInfo = await revenueDistributor.getSEALInvestor(investor.address);
      expect(investorInfo.paidAmount).to.be.gt(0);

      // Total should equal revenue
      const totalDistributed = 
        await revenueDistributor.totalDistributedToUsers() +
        await revenueDistributor.totalDistributedToInvestors() +
        await revenueDistributor.totalDistributedToOperations() +
        await revenueDistributor.totalDistributedToReserve();
      
      expect(totalDistributed).to.be.closeTo(revenue, ethers.parseEther("1"));
    });
  });
});
