/**
 * Terracare Ledger - Sovereign Health Infrastructure Deployment
 * 
 * This script deploys the complete 9-system ecosystem:
 * 1. SovereignIdentity - Master identity registry
 * 2. AccessGovernor - Cross-system permission orchestrator
 * 3. AuditTrail - Immutable event log
 * 4. TholosAdapter - Clinical records
 * 5. HarmonicAdapter - Biofeedback/wellness
 * 6. TerratoneAdapter - Frequency therapy
 * 7. SofieOSAdapter - Core OS integration
 * 8. LlamaAdapter - AI inference audit
 * 9. MapAdapter - Geographic sovereignty
 * 10. PoAConsensus - Validator consensus
 * 
 * Pillar-7: Automated deployment - zero manual steps
 */

const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("╔════════════════════════════════════════════════════════════╗");
  console.log("║   TERRACARE SOVEREIGN HEALTH INFRASTRUCTURE DEPLOYMENT    ║");
  console.log("║           Tokenless • Gasless • Hash-Only                 ║");
  console.log("╚════════════════════════════════════════════════════════════╝");
  console.log("\nDeploying with:", deployer.address);
  console.log("Network:", hre.network.name);
  console.log("Chain ID:", (await hre.ethers.provider.getNetwork()).chainId);
  console.log("\n");

  const deployments = {
    network: hre.network.name,
    chainId: (await hre.ethers.provider.getNetwork()).chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {}
  };

  // ============ PHASE 1: Core Infrastructure ============
  console.log("📦 PHASE 1: Deploying Core Infrastructure...\n");

  // Deploy SovereignIdentity
  console.log("Deploying SovereignIdentity...");
  const SovereignIdentity = await hre.ethers.getContractFactory("SovereignIdentity");
  const sovereignIdentity = await SovereignIdentity.deploy();
  await sovereignIdentity.waitForDeployment();
  deployments.contracts.SovereignIdentity = {
    address: await sovereignIdentity.getAddress(),
    name: "SovereignIdentity"
  };
  console.log("✓ SovereignIdentity:", await sovereignIdentity.getAddress());

  // Deploy AccessGovernor
  console.log("Deploying AccessGovernor...");
  const AccessGovernor = await hre.ethers.getContractFactory("AccessGovernor");
  const accessGovernor = await AccessGovernor.deploy(await sovereignIdentity.getAddress());
  await accessGovernor.waitForDeployment();
  deployments.contracts.AccessGovernor = {
    address: await accessGovernor.getAddress(),
    name: "AccessGovernor"
  };
  console.log("✓ AccessGovernor:", await accessGovernor.getAddress());

  // Deploy AuditTrail
  console.log("Deploying AuditTrail...");
  const AuditTrail = await hre.ethers.getContractFactory("AuditTrail");
  const auditTrail = await AuditTrail.deploy(sovereignIdentity.address);
  await auditTrail.waitForDeployment();
  deployments.contracts.AuditTrail = {
    address: await auditTrail.getAddress(),
    name: "AuditTrail"
  };
  console.log("✓ AuditTrail:", await auditTrail.getAddress());

  // ============ PHASE 2: System Adapters ============
  console.log("\n📦 PHASE 2: Deploying System Adapters...\n");

  // Deploy TholosAdapter
  console.log("Deploying TholosAdapter...");
  const TholosAdapter = await hre.ethers.getContractFactory("TholosAdapter");
  const tholosAdapter = await TholosAdapter.deploy(
    await sovereignIdentity.getAddress(),
    await accessGovernor.getAddress(),
    await auditTrail.getAddress()
  );
  await tholosAdapter.waitForDeployment();
  deployments.contracts.TholosAdapter = {
    address: await tholosAdapter.getAddress(),
    name: "TholosAdapter",
    system: "Tholos"
  };
  console.log("✓ TholosAdapter:", await tholosAdapter.getAddress());

  // Deploy HarmonicAdapter
  console.log("Deploying HarmonicAdapter...");
  const HarmonicAdapter = await hre.ethers.getContractFactory("HarmonicAdapter");
  const harmonicAdapter = await HarmonicAdapter.deploy(
    await sovereignIdentity.getAddress(),
    await accessGovernor.getAddress(),
    auditTrail.address
  );
  await harmonicAdapter.waitForDeployment();
  deployments.contracts.HarmonicAdapter = {
    address: await harmonicAdapter.getAddress(),
    name: "HarmonicAdapter",
    system: "Harmonic"
  };
  console.log("✓ HarmonicAdapter:", await harmonicAdapter.getAddress());

  // Deploy TerratoneAdapter
  console.log("Deploying TerratoneAdapter...");
  const TerratoneAdapter = await hre.ethers.getContractFactory("TerratoneAdapter");
  const terratoneAdapter = await TerratoneAdapter.deploy(
    await sovereignIdentity.getAddress(),
    await accessGovernor.getAddress(),
    auditTrail.address
  );
  await terratoneAdapter.waitForDeployment();
  deployments.contracts.TerratoneAdapter = {
    address: await terratoneAdapter.getAddress(),
    name: "TerratoneAdapter",
    system: "Terratone"
  };
  console.log("✓ TerratoneAdapter:", await terratoneAdapter.getAddress());

  // Deploy SofieOSAdapter
  console.log("Deploying SofieOSAdapter...");
  const SofieOSAdapter = await hre.ethers.getContractFactory("SofieOSAdapter");
  const sofieOSAdapter = await SofieOSAdapter.deploy(
    await sovereignIdentity.getAddress(),
    await accessGovernor.getAddress(),
    auditTrail.address
  );
  await sofieOSAdapter.waitForDeployment();
  deployments.contracts.SofieOSAdapter = {
    address: await sofieOSAdapter.getAddress(),
    name: "SofieOSAdapter",
    system: "SofieOS"
  };
  console.log("✓ SofieOSAdapter:", await sofieOSAdapter.getAddress());

  // Deploy LlamaAdapter
  console.log("Deploying LlamaAdapter...");
  const LlamaAdapter = await hre.ethers.getContractFactory("LlamaAdapter");
  const llamaAdapter = await LlamaAdapter.deploy(
    await sovereignIdentity.getAddress(),
    await accessGovernor.getAddress(),
    auditTrail.address
  );
  await llamaAdapter.waitForDeployment();
  deployments.contracts.LlamaAdapter = {
    address: await llamaAdapter.getAddress(),
    name: "LlamaAdapter",
    system: "LlamaBackend"
  };
  console.log("✓ LlamaAdapter:", await llamaAdapter.getAddress());

  // Deploy MapAdapter
  console.log("Deploying MapAdapter...");
  const MapAdapter = await hre.ethers.getContractFactory("MapAdapter");
  const mapAdapter = await MapAdapter.deploy(
    await sovereignIdentity.getAddress(),
    await accessGovernor.getAddress(),
    auditTrail.address
  );
  await mapAdapter.waitForDeployment();
  deployments.contracts.MapAdapter = {
    address: await mapAdapter.getAddress(),
    name: "MapAdapter",
    system: "MapSystem"
  };
  console.log("✓ MapAdapter:", await mapAdapter.getAddress());

  // ============ PHASE 3: PoA Consensus ============
  console.log("\n📦 PHASE 3: Deploying PoA Consensus...\n");

  // Deploy PoAConsensus
  console.log("Deploying PoAConsensus...");
  const PoAConsensus = await hre.ethers.getContractFactory("PoAConsensus");
  const poaConsensus = await PoAConsensus.deploy(
    await sovereignIdentity.getAddress(),
    auditTrail.address
  );
  await poaConsensus.waitForDeployment();
  deployments.contracts.PoAConsensus = {
    address: await poaConsensus.getAddress(),
    name: "PoAConsensus",
    system: "SandIronNode"
  };
  console.log("✓ PoAConsensus:", await poaConsensus.getAddress());

  // ============ PHASE 4: System Configuration ============
  console.log("\n📦 PHASE 4: Configuring Cross-System Connections...\n");

  // Set system adapters in SovereignIdentity
  console.log("Setting system adapters in SovereignIdentity...");
  
  const SystemType = {
    Unknown: 0,
    Heartware: 1,
    Tholos: 2,
    Harmonic: 3,
    Terratone: 4,
    SofieOS: 5,
    LlamaBackend: 6,
    MapSystem: 7,
    SandIronNode: 8,
    Emergency: 9
  };

  await (await sovereignIdentity.setSystemAdapter(SystemType.Tholos, tholosAdapter.address)).wait();
  await (await sovereignIdentity.setSystemAdapter(SystemType.Harmonic, harmonicAdapter.address)).wait();
  await (await sovereignIdentity.setSystemAdapter(SystemType.Terratone, terratoneAdapter.address)).wait();
  await (await sovereignIdentity.setSystemAdapter(SystemType.SofieOS, sofieOSAdapter.address)).wait();
  await (await sovereignIdentity.setSystemAdapter(SystemType.LlamaBackend, llamaAdapter.address)).wait();
  await (await sovereignIdentity.setSystemAdapter(SystemType.MapSystem, mapAdapter.address)).wait();
  await (await sovereignIdentity.setSystemAdapter(SystemType.SandIronNode, poaConsensus.address)).wait();

  console.log("✓ All system adapters configured");

  // ============ PHASE 5: Register Action Types ============
  console.log("\n📦 PHASE 5: Registering Audit Action Types...\n");

  // Register common action types
  const actionTypes = [
    { hash: hre.ethers.utils?.keccak256?.(hre.ethers.utils.toUtf8Bytes("CREATE_RECORD")) || 
            hre.ethers.keccak256(hre.ethers.toUtf8Bytes("CREATE_RECORD")), 
      name: "Create Clinical Record", system: SystemType.Tholos },
    { hash: hre.ethers.utils?.keccak256?.(hre.ethers.utils.toUtf8Bytes("UPDATE_RECORD")) ||
            hre.ethers.keccak256(hre.ethers.toUtf8Bytes("UPDATE_RECORD")), 
      name: "Update Clinical Record", system: SystemType.Tholos },
    { hash: hre.ethers.utils?.keccak256?.(hre.ethers.utils.toUtf8Bytes("BIOFEEDBACK_SESSION")) ||
            hre.ethers.keccak256(hre.ethers.toUtf8Bytes("BIOFEEDBACK_SESSION")), 
      name: "Biofeedback Session", system: SystemType.Harmonic },
    { hash: hre.ethers.utils?.keccak256?.(hre.ethers.utils.toUtf8Bytes("TREATMENT_SESSION")) ||
            hre.ethers.keccak256(hre.ethers.toUtf8Bytes("TREATMENT_SESSION")), 
      name: "Frequency Treatment", system: SystemType.Terratone },
    { hash: hre.ethers.utils?.keccak256?.(hre.ethers.utils.toUtf8Bytes("RECOMMENDATION_GENERATED")) ||
            hre.ethers.keccak256(hre.ethers.toUtf8Bytes("RECOMMENDATION_GENERATED")), 
      name: "AI Recommendation", system: SystemType.LlamaBackend },
    { hash: hre.ethers.utils?.keccak256?.(hre.ethers.utils.toUtf8Bytes("DEVICE_REGISTERED")) ||
            hre.ethers.keccak256(hre.ethers.toUtf8Bytes("DEVICE_REGISTERED")), 
      name: "Device Registration", system: SystemType.SofieOS },
  ];

  for (const action of actionTypes) {
    try {
      await (await auditTrail.registerActionType(
        action.hash,
        action.name,
        action.system,
        true,  // requiresConsent
        2555   // retentionDays (~7 years for HIPAA)
      )).wait();
    } catch (e) {
      console.log(`Note: Action type registration skipped (may already exist)`);
    }
  }
  console.log("✓ Action types registered");

  // ============ PHASE 6: Generate Configuration ============
  console.log("\n📦 PHASE 6: Generating Configuration Files...\n");

  // Save deployment info
  const deploymentPath = path.join(__dirname, "..", "artifacts", "deployment.json");
  fs.mkdirSync(path.dirname(deploymentPath), { recursive: true });
  fs.writeFileSync(deploymentPath, JSON.stringify(deployments, null, 2));
  console.log("✓ Deployment saved to:", deploymentPath);

  // Generate .env file for sibling repos
  const envContent = `
# Terracare Ledger Deployment Configuration
# Generated: ${deployments.timestamp}
# Network: ${deployments.network}
# Chain ID: ${deployments.chainId}

# Core Contracts
TERRACARE_SOVEREIGN_IDENTITY=${sovereignIdentity.address}
TERRACARE_ACCESS_GOVERNOR=${await accessGovernor.getAddress()}
TERRACARE_AUDIT_TRAIL=${auditTrail.address}

# System Adapters
TERRACARE_THOLOS_ADAPTER=${tholosAdapter.address}
TERRACARE_HARMONIC_ADAPTER=${harmonicAdapter.address}
TERRACARE_TERRATONE_ADAPTER=${terratoneAdapter.address}
TERRACARE_SOFIEOS_ADAPTER=${sofieOSAdapter.address}
TERRACARE_LLAMA_ADAPTER=${llamaAdapter.address}
TERRACARE_MAP_ADAPTER=${mapAdapter.address}

# Consensus
TERRACARE_POA_CONSENSUS=${poaConsensus.address}

# Network
TERRACARE_CHAIN_ID=${deployments.chainId}
TERRACARE_RPC_URL=${hre.network.config.url || "http://localhost:8545"}
`;

  const envPath = path.join(__dirname, "..", "artifacts", ".env.deployed");
  fs.writeFileSync(envPath, envContent.trim());
  console.log("✓ Environment file saved to:", envPath);

  // Generate ABIs package
  const abiPackage = {
    name: "terracare-contracts",
    version: "0.1.0-sovereign",
    contracts: {}
  };

  const contractNames = [
    "SovereignIdentity",
    "AccessGovernor",
    "AuditTrail",
    "TholosAdapter",
    "HarmonicAdapter",
    "TerratoneAdapter",
    "SofieOSAdapter",
    "LlamaAdapter",
    "MapAdapter",
    "PoAConsensus"
  ];

  for (const name of contractNames) {
    const artifact = await hre.artifacts.readArtifact(name);
    abiPackage.contracts[name] = {
      abi: artifact.abi,
      bytecode: artifact.bytecode,
      address: deployments.contracts[name]?.address
    };
  }

  const abiPath = path.join(__dirname, "..", "artifacts", "abis.json");
  fs.writeFileSync(abiPath, JSON.stringify(abiPackage, null, 2));
  console.log("✓ ABIs package saved to:", abiPath);

  // ============ SUMMARY ============
  console.log("\n╔════════════════════════════════════════════════════════════╗");
  console.log("║                  DEPLOYMENT COMPLETE                       ║");
  console.log("╚════════════════════════════════════════════════════════════╝\n");

  console.log("📋 Contract Addresses:");
  console.log("─────────────────────────────────────────────────────────────");
  console.log("Core Infrastructure:");
  console.log("  SovereignIdentity: ", sovereignIdentity.address);
  console.log("  AccessGovernor:    ", accessGovernor.address);
  console.log("  AuditTrail:        ", auditTrail.address);
  console.log("\nSystem Adapters:");
  console.log("  TholosAdapter:     ", tholosAdapter.address);
  console.log("  HarmonicAdapter:   ", harmonicAdapter.address);
  console.log("  TerratoneAdapter:  ", terratoneAdapter.address);
  console.log("  SofieOSAdapter:    ", sofieOSAdapter.address);
  console.log("  LlamaAdapter:      ", llamaAdapter.address);
  console.log("  MapAdapter:        ", mapAdapter.address);
  console.log("\nConsensus:");
  console.log("  PoAConsensus:      ", poaConsensus.address);
  console.log("─────────────────────────────────────────────────────────────\n");

  console.log("🔐 Next Steps:");
  console.log("  1. Copy artifacts/.env.deployed to sibling repos");
  console.log("  2. Register validators: npx hardhat run scripts/setup-validators.js");
  console.log("  3. Run integration tests: npm test");
  console.log("  4. Tag release: git tag v0.1.0-sovereign");
  console.log("\n✨ Terracare Sovereign Infrastructure is ready!");
}

main().catch((error) => {
  console.error("\n❌ Deployment failed:", error);
  process.exitCode = 1;
});
