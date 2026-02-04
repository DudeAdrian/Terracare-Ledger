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
  console.log("\nDeploying with:", await deployer.getAddress());
  console.log("Network:", hre.network.name);
  console.log("Chain ID:", (await hre.ethers.provider.getNetwork()).chainId);
  console.log("\n");

  const deployments = {
    network: hre.network.name,
    chainId: (await hre.ethers.provider.getNetwork()).chainId,
    deployer: await deployer.getAddress(),
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
  const sovereignIdentityAddress = await sovereignIdentity.getAddress();
  deployments.contracts.SovereignIdentity = {
    address: sovereignIdentityAddress,
    name: "SovereignIdentity"
  };
  console.log("✓ SovereignIdentity:", sovereignIdentityAddress);

  // Deploy AccessGovernor
  console.log("Deploying AccessGovernor...");
  const AccessGovernor = await hre.ethers.getContractFactory("AccessGovernor");
  const accessGovernor = await AccessGovernor.deploy();
  await accessGovernor.waitForDeployment();
  const accessGovernorAddress = await accessGovernor.getAddress();
  deployments.contracts.AccessGovernor = {
    address: accessGovernorAddress,
    name: "AccessGovernor"
  };
  console.log("✓ AccessGovernor:", accessGovernorAddress);

  // Deploy AuditTrail
  console.log("Deploying AuditTrail...");
  const AuditTrail = await hre.ethers.getContractFactory("AuditTrail");
  const auditTrail = await AuditTrail.deploy();
  await auditTrail.waitForDeployment();
  const auditTrailAddress = await auditTrail.getAddress();
  deployments.contracts.AuditTrail = {
    address: auditTrailAddress,
    name: "AuditTrail"
  };
  console.log("✓ AuditTrail:", auditTrailAddress);

  // ============ PHASE 2: System Adapters ============
  console.log("\n📦 PHASE 2: Deploying System Adapters...\n");

  // Deploy TholosAdapter
  console.log("Deploying TholosAdapter...");
  const TholosAdapter = await hre.ethers.getContractFactory("TholosAdapter");
  const tholosAdapter = await TholosAdapter.deploy(
    sovereignIdentityAddress,
    accessGovernorAddress,
    auditTrailAddress
  );
  await tholosAdapter.waitForDeployment();
  const tholosAdapterAddress = await tholosAdapter.getAddress();
  deployments.contracts.TholosAdapter = {
    address: tholosAdapterAddress,
    name: "TholosAdapter",
    system: "Tholos"
  };
  console.log("✓ TholosAdapter:", tholosAdapterAddress);

  // Deploy HarmonicAdapter
  console.log("Deploying HarmonicAdapter...");
  const HarmonicAdapter = await hre.ethers.getContractFactory("HarmonicAdapter");
  const harmonicAdapter = await HarmonicAdapter.deploy(
    sovereignIdentityAddress,
    accessGovernorAddress,
    auditTrailAddress
  );
  await harmonicAdapter.waitForDeployment();
  const harmonicAdapterAddress = await harmonicAdapter.getAddress();
  deployments.contracts.HarmonicAdapter = {
    address: harmonicAdapterAddress,
    name: "HarmonicAdapter",
    system: "Harmonic"
  };
  console.log("✓ HarmonicAdapter:", harmonicAdapterAddress);

  // Deploy TerratoneAdapter
  console.log("Deploying TerratoneAdapter...");
  const TerratoneAdapter = await hre.ethers.getContractFactory("TerratoneAdapter");
  const terratoneAdapter = await TerratoneAdapter.deploy(
    sovereignIdentityAddress,
    accessGovernorAddress,
    auditTrailAddress
  );
  await terratoneAdapter.waitForDeployment();
  const terratoneAdapterAddress = await terratoneAdapter.getAddress();
  deployments.contracts.TerratoneAdapter = {
    address: terratoneAdapterAddress,
    name: "TerratoneAdapter",
    system: "Terratone"
  };
  console.log("✓ TerratoneAdapter:", terratoneAdapterAddress);

  // Deploy SofieOSAdapter
  console.log("Deploying SofieOSAdapter...");
  const SofieOSAdapter = await hre.ethers.getContractFactory("SofieOSAdapter");
  const sofieOSAdapter = await SofieOSAdapter.deploy(
    sovereignIdentityAddress,
    accessGovernorAddress,
    auditTrailAddress
  );
  await sofieOSAdapter.waitForDeployment();
  const sofieOSAdapterAddress = await sofieOSAdapter.getAddress();
  deployments.contracts.SofieOSAdapter = {
    address: sofieOSAdapterAddress,
    name: "SofieOSAdapter",
    system: "SofieOS"
  };
  console.log("✓ SofieOSAdapter:", sofieOSAdapterAddress);

  // Deploy LlamaAdapter
  console.log("Deploying LlamaAdapter...");
  const LlamaAdapter = await hre.ethers.getContractFactory("LlamaAdapter");
  const llamaAdapter = await LlamaAdapter.deploy(
    sovereignIdentityAddress,
    accessGovernorAddress,
    auditTrailAddress
  );
  await llamaAdapter.waitForDeployment();
  const llamaAdapterAddress = await llamaAdapter.getAddress();
  deployments.contracts.LlamaAdapter = {
    address: llamaAdapterAddress,
    name: "LlamaAdapter",
    system: "LlamaBackend"
  };
  console.log("✓ LlamaAdapter:", llamaAdapterAddress);

  // Deploy MapAdapter
  console.log("Deploying MapAdapter...");
  const MapAdapter = await hre.ethers.getContractFactory("MapAdapter");
  const mapAdapter = await MapAdapter.deploy(
    sovereignIdentityAddress,
    accessGovernorAddress,
    auditTrailAddress
  );
  await mapAdapter.waitForDeployment();
  const mapAdapterAddress = await mapAdapter.getAddress();
  deployments.contracts.MapAdapter = {
    address: mapAdapterAddress,
    name: "MapAdapter",
    system: "MapSystem"
  };
  console.log("✓ MapAdapter:", mapAdapterAddress);

  // ============ PHASE 3: PoA Consensus ============
  console.log("\n📦 PHASE 3: Deploying PoA Consensus...\n");

  // Deploy PoAConsensus
  console.log("Deploying PoAConsensus...");
  const PoAConsensus = await hre.ethers.getContractFactory("PoAConsensus");
  const poaConsensus = await PoAConsensus.deploy(
    sovereignIdentityAddress,
    auditTrailAddress
  );
  await poaConsensus.waitForDeployment();
  const poaConsensusAddress = await poaConsensus.getAddress();
  deployments.contracts.PoAConsensus = {
    address: poaConsensusAddress,
    name: "PoAConsensus",
    system: "SandIronNode"
  };
  console.log("✓ PoAConsensus:", poaConsensusAddress);

  // ============ PHASE 4: Generate Configuration ============
  console.log("\n📦 PHASE 4: Generating Configuration Files...\n");

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
TERRACARE_SOVEREIGN_IDENTITY=${sovereignIdentityAddress}
TERRACARE_ACCESS_GOVERNOR=${accessGovernorAddress}
TERRACARE_AUDIT_TRAIL=${auditTrailAddress}

# System Adapters
TERRACARE_THOLOS_ADAPTER=${tholosAdapterAddress}
TERRACARE_HARMONIC_ADAPTER=${harmonicAdapterAddress}
TERRACARE_TERRATONE_ADAPTER=${terratoneAdapterAddress}
TERRACARE_SOFIEOS_ADAPTER=${sofieOSAdapterAddress}
TERRACARE_LLAMA_ADAPTER=${llamaAdapterAddress}
TERRACARE_MAP_ADAPTER=${mapAdapterAddress}

# Consensus
TERRACARE_POA_CONSENSUS=${poaConsensusAddress}

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
  console.log("  SovereignIdentity: ", sovereignIdentityAddress);
  console.log("  AccessGovernor:    ", accessGovernorAddress);
  console.log("  AuditTrail:        ", auditTrailAddress);
  console.log("\nSystem Adapters:");
  console.log("  TholosAdapter:     ", tholosAdapterAddress);
  console.log("  HarmonicAdapter:   ", harmonicAdapterAddress);
  console.log("  TerratoneAdapter:  ", terratoneAdapterAddress);
  console.log("  SofieOSAdapter:    ", sofieOSAdapterAddress);
  console.log("  LlamaAdapter:      ", llamaAdapterAddress);
  console.log("  MapAdapter:        ", mapAdapterAddress);
  console.log("\nConsensus:");
  console.log("  PoAConsensus:      ", poaConsensusAddress);
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
