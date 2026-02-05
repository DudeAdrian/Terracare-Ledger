/**
 * TerraCare Ledger v2.0 - Participation Layer Deployment Script
 * 
 * Deploys:
 * 1. TokenEngine (MINE + WELL dual-token system)
 * 2. ActivityRegistry (activity logging with rate limits)
 * 3. RevenueDistributor (cooperative revenue model)
 * 4. GovernanceBridge (timelock transition to cooperative ownership)
 * 
 * Links to existing IdentityRegistry and sets up SEAL investor terms.
 */

const { ethers, run } = require("hardhat");
const fs = require("fs");
const path = require("path");

// Configuration
const CONFIG = {
  // SEAL Investor Configuration
  SEAL_INVESTOR_ADDRESS: process.env.SEAL_INVESTOR_ADDRESS || "0x0000000000000000000000000000000000000000",
  SEAL_INVESTMENT_AMOUNT: ethers.parseEther("750000"), // $750K equivalent in ETH
  SEAL_CAP_MULTIPLIER: 300, // 3x cap (300%)
  
  // Treasury addresses (can be same as deployer for testing)
  USER_BUYBACK_TREASURY: process.env.USER_BUYBACK_TREASURY || "",
  OPERATIONS_TREASURY: process.env.OPERATIONS_TREASURY || "",
  RESERVE_TREASURY: process.env.RESERVE_TREASURY || "",
  
  // Initial validators for PoA phase
  INITIAL_VALIDATORS: process.env.INITIAL_VALIDATORS 
    ? process.env.INITIAL_VALIDATORS.split(",") 
    : [],
  
  // Existing contract addresses (from previous deployment)
  IDENTITY_REGISTRY_ADDRESS: process.env.IDENTITY_REGISTRY_ADDRESS || "",
  ACCESS_CONTROL_ADDRESS: process.env.ACCESS_CONTROL_ADDRESS || "",
  RECORD_REGISTRY_ADDRESS: process.env.RECORD_REGISTRY_ADDRESS || "",
  AUDIT_LOG_ADDRESS: process.env.AUDIT_LOG_ADDRESS || "",
};

async function main() {
  console.log("🚀 TerraCare Ledger v2.0 - Participation Layer Deployment");
  console.log("==========================================================\n");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  console.log("Account balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH\n");

  // Get network info
  const network = await ethers.provider.getNetwork();
  console.log("Network:", network.name, "(chainId:", network.chainId.toString() + ")\n");

  const deployedContracts = {};

  // ============================================
  // STEP 1: Deploy TokenEngine
  // ============================================
  console.log("📦 STEP 1: Deploying TokenEngine...");
  const TokenEngine = await ethers.getContractFactory("TokenEngine");
  const tokenEngine = await TokenEngine.deploy();
  await tokenEngine.waitForDeployment();
  deployedContracts.TokenEngine = await tokenEngine.getAddress();
  console.log("✅ TokenEngine deployed to:", deployedContracts.TokenEngine);

  // ============================================
  // STEP 2: Deploy ActivityRegistry
  // ============================================
  console.log("\n📦 STEP 2: Deploying ActivityRegistry...");
  
  // Check if IdentityRegistry address is provided
  let identityRegistryAddress = CONFIG.IDENTITY_REGISTRY_ADDRESS;
  if (!identityRegistryAddress) {
    console.log("⚠️  No IdentityRegistry address provided, deploying new one...");
    const IdentityRegistry = await ethers.getContractFactory("IdentityRegistry");
    const identityRegistry = await IdentityRegistry.deploy();
    await identityRegistry.waitForDeployment();
    identityRegistryAddress = await identityRegistry.getAddress();
    deployedContracts.IdentityRegistry = identityRegistryAddress;
    console.log("✅ IdentityRegistry deployed to:", identityRegistryAddress);
  }

  const ActivityRegistry = await ethers.getContractFactory("ActivityRegistry");
  const activityRegistry = await ActivityRegistry.deploy(
    deployedContracts.TokenEngine,
    identityRegistryAddress
  );
  await activityRegistry.waitForDeployment();
  deployedContracts.ActivityRegistry = await activityRegistry.getAddress();
  console.log("✅ ActivityRegistry deployed to:", deployedContracts.ActivityRegistry);

  // Grant minter role to ActivityRegistry
  console.log("  Granting MINTER_ROLE to ActivityRegistry...");
  await (await tokenEngine.grantMinterRole(deployedContracts.ActivityRegistry)).wait();
  console.log("  ✅ Minter role granted");

  // ============================================
  // STEP 3: Deploy RevenueDistributor
  // ============================================
  console.log("\n📦 STEP 3: Deploying RevenueDistributor...");

  // Use deployer as treasury if not specified
  const userTreasury = CONFIG.USER_BUYBACK_TREASURY || deployer.address;
  const opsTreasury = CONFIG.OPERATIONS_TREASURY || deployer.address;
  const reserveTreasury = CONFIG.RESERVE_TREASURY || deployer.address;

  const RevenueDistributor = await ethers.getContractFactory("RevenueDistributor");
  const revenueDistributor = await RevenueDistributor.deploy(
    deployedContracts.TokenEngine,
    userTreasury,
    opsTreasury,
    reserveTreasury
  );
  await revenueDistributor.waitForDeployment();
  deployedContracts.RevenueDistributor = await revenueDistributor.getAddress();
  console.log("✅ RevenueDistributor deployed to:", deployedContracts.RevenueDistributor);

  // Add SEAL investor if address is valid
  if (CONFIG.SEAL_INVESTOR_ADDRESS !== "0x0000000000000000000000000000000000000000") {
    console.log("  Adding SEAL investor...");
    await (await revenueDistributor.addSEALInvestor(
      CONFIG.SEAL_INVESTOR_ADDRESS,
      CONFIG.SEAL_INVESTMENT_AMOUNT,
      CONFIG.SEAL_CAP_MULTIPLIER
    )).wait();
    console.log("  ✅ SEAL investor added");
    console.log(`     Address: ${CONFIG.SEAL_INVESTOR_ADDRESS}`);
    console.log(`     Investment: ${ethers.formatEther(CONFIG.SEAL_INVESTMENT_AMOUNT)} ETH`);
    console.log(`     Cap: ${CONFIG.SEAL_CAP_MULTIPLIER / 100}x (${ethers.formatEther(CONFIG.SEAL_INVESTMENT_AMOUNT * BigInt(CONFIG.SEAL_CAP_MULTIPLIER) / 100n)} ETH)`);
  } else {
    console.log("  ⚠️  No SEAL investor address configured, skipping...");
  }

  // ============================================
  // STEP 4: Deploy GovernanceBridge
  // ============================================
  console.log("\n📦 STEP 4: Deploying GovernanceBridge...");

  // Use deployer and additional signers as validators if not specified
  let validators = CONFIG.INITIAL_VALIDATORS;
  if (validators.length < 2) {
    // Get additional signers for validators
    const signers = await ethers.getSigners();
    validators = [deployer.address];
    if (signers.length > 1) {
      validators.push(signers[1].address);
    } else {
      // Create a second validator address
      const wallet = ethers.Wallet.createRandom();
      validators.push(wallet.address);
      console.log("  ⚠️  Created random validator address:", wallet.address);
    }
  }

  const GovernanceBridge = await ethers.getContractFactory("GovernanceBridge");
  const governanceBridge = await GovernanceBridge.deploy(
    deployedContracts.TokenEngine,
    identityRegistryAddress,
    validators
  );
  await governanceBridge.waitForDeployment();
  deployedContracts.GovernanceBridge = await governanceBridge.getAddress();
  console.log("✅ GovernanceBridge deployed to:", deployedContracts.GovernanceBridge);
  console.log("  Initial validators:", validators.join(", "));

  // ============================================
  // STEP 5: Link TokenEngine to existing contracts
  // ============================================
  console.log("\n🔗 STEP 5: Linking contracts...");

  // Update IdentityRegistry with TokenEngine
  if (deployedContracts.IdentityRegistry) {
    const identityRegistry = await ethers.getContractAt("IdentityRegistry", deployedContracts.IdentityRegistry);
    await (await identityRegistry.setTokenEngine(deployedContracts.TokenEngine)).wait();
    console.log("✅ IdentityRegistry linked to TokenEngine");
  }

  // Update AccessControl with TokenEngine
  if (CONFIG.ACCESS_CONTROL_ADDRESS) {
    const accessControl = await ethers.getContractAt("AccessControl", CONFIG.ACCESS_CONTROL_ADDRESS);
    // Note: setTokenEngine in AccessControl requires special permission
    console.log("⚠️  Please manually link AccessControl to TokenEngine");
  }

  // Update RecordRegistry with ActivityRegistry
  if (CONFIG.RECORD_REGISTRY_ADDRESS) {
    const recordRegistry = await ethers.getContractAt("RecordRegistry", CONFIG.RECORD_REGISTRY_ADDRESS);
    // Set authorized activity caller
    await (await recordRegistry.setAuthorizedActivityCaller(deployedContracts.ActivityRegistry)).wait();
    console.log("✅ RecordRegistry linked to ActivityRegistry");
  }

  // ============================================
  // STEP 6: Grant roles
  // ============================================
  console.log("\n🔐 STEP 6: Granting roles...");

  // Grant ORACLE_ROLE to deployer (will be transferred to backend/oracle service)
  await (await activityRegistry.grantRole(await activityRegistry.ORACLE_ROLE(), deployer.address)).wait();
  console.log("✅ ORACLE_ROLE granted to deployer on ActivityRegistry");

  // Grant DISTRIBUTOR_ROLE to deployer (for webhook integration)
  await (await revenueDistributor.grantRole(await revenueDistributor.DISTRIBUTOR_ROLE(), deployer.address)).wait();
  console.log("✅ DISTRIBUTOR_ROLE granted to deployer on RevenueDistributor");

  // ============================================
  // STEP 7: Save deployment info
  // ============================================
  console.log("\n💾 STEP 7: Saving deployment info...");

  const deploymentInfo = {
    network: {
      name: network.name,
      chainId: Number(network.chainId),
    },
    deployer: deployer.address,
    deployedAt: new Date().toISOString(),
    contracts: deployedContracts,
    configuration: {
      SEAL_INVESTOR_ADDRESS: CONFIG.SEAL_INVESTOR_ADDRESS,
      SEAL_CAP_MULTIPLIER: CONFIG.SEAL_CAP_MULTIPLIER,
      INITIAL_VALIDATORS: validators,
    },
  };

  const artifactsDir = path.join(__dirname, "..", "artifacts");
  if (!fs.existsSync(artifactsDir)) {
    fs.mkdirSync(artifactsDir, { recursive: true });
  }

  const deploymentPath = path.join(artifactsDir, `deployment-v2-${network.chainId}.json`);
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  console.log(`✅ Deployment info saved to: ${deploymentPath}`);

  // Also save as latest
  const latestPath = path.join(artifactsDir, "deployment-v2-latest.json");
  fs.writeFileSync(latestPath, JSON.stringify(deploymentInfo, null, 2));

  // Create .env.example update
  const envContent = `
# TerraCare Ledger v2.0 - Participation Layer Contracts
TERRACARE_TOKEN_ENGINE=${deployedContracts.TokenEngine}
TERRACARE_ACTIVITY_REGISTRY=${deployedContracts.ActivityRegistry}
TERRACARE_REVENUE_DISTRIBUTOR=${deployedContracts.RevenueDistributor}
TERRACARE_GOVERNANCE_BRIDGE=${deployedContracts.GovernanceBridge}
${deployedContracts.IdentityRegistry ? `TERRACARE_IDENTITY_REGISTRY=${deployedContracts.IdentityRegistry}` : `TERRACARE_IDENTITY_REGISTRY=${CONFIG.IDENTITY_REGISTRY_ADDRESS}`}
`;

  const envPath = path.join(artifactsDir, ".env.v2.contracts");
  fs.writeFileSync(envPath, envContent);
  console.log(`✅ Environment variables saved to: ${envPath}`);

  // ============================================
  // STEP 8: Verify contracts (if on public network)
  // ============================================
  if (network.chainId !== 1337n && network.chainId !== 31337n) {
    console.log("\n🔍 STEP 8: Verifying contracts...");
    console.log("(Skipping verification for private network)");
    
    // Uncomment for public networks:
    // await verifyContract(deployedContracts.TokenEngine, []);
    // await verifyContract(deployedContracts.ActivityRegistry, [deployedContracts.TokenEngine, identityRegistryAddress]);
    // await verifyContract(deployedContracts.RevenueDistributor, [deployedContracts.TokenEngine, userTreasury, opsTreasury, reserveTreasury]);
    // await verifyContract(deployedContracts.GovernanceBridge, [deployedContracts.TokenEngine, identityRegistryAddress, validators]);
  }

  // ============================================
  // Summary
  // ============================================
  console.log("\n" + "=".repeat(60));
  console.log("🎉 DEPLOYMENT COMPLETE!");
  console.log("=".repeat(60));
  console.log("\nDeployed Contracts:");
  console.log("-------------------");
  for (const [name, address] of Object.entries(deployedContracts)) {
    console.log(`${name.padEnd(20)}: ${address}`);
  }
  console.log("\nNext Steps:");
  console.log("-----------");
  console.log("1. Transfer ORACLE_ROLE to your backend/oracle service");
  console.log("2. Configure webhook endpoint for RevenueDistributor");
  console.log("3. Set up AI signer service for activity validation");
  console.log("4. Update API Gateway with new contract addresses");
  console.log("5. Test the participation layer with test activities");
  console.log("\n" + "=".repeat(60));
}

async function verifyContract(address, constructorArguments) {
  try {
    await run("verify:verify", {
      address,
      constructorArguments,
    });
    console.log(`✅ Verified: ${address}`);
  } catch (error) {
    console.log(`❌ Failed to verify ${address}:`, error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Deployment failed:", error);
    process.exit(1);
  });
