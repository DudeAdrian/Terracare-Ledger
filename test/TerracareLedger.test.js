const { expect } = require("chai");
const hre = require("hardhat");

describe("Terracare Ledger - 6 Phase Build Test", function () {
  let deployer, provider, practitioner, user;
  
  before(async function () {
    [deployer, provider, practitioner, user] = await hre.ethers.getSigners();
  });

  describe("Phase 1: Core Infrastructure", function () {
    it("Should deploy SovereignIdentity", async function () {
      const SovereignIdentity = await hre.ethers.getContractFactory("SovereignIdentity");
      const sovereignIdentity = await SovereignIdentity.deploy();
      await sovereignIdentity.waitForDeployment();
      
      const address = await sovereignIdentity.getAddress();
      expect(address).to.be.properAddress;
      expect(address).to.not.equal(hre.ethers.ZeroAddress);
      console.log("    Deployed at:", address);
    });

    it("Should deploy AccessGovernor", async function () {
      const AccessGovernor = await hre.ethers.getContractFactory("AccessGovernor");
      const accessGovernor = await AccessGovernor.deploy();
      await accessGovernor.waitForDeployment();
      
      expect(await accessGovernor.getAddress()).to.be.properAddress;
      console.log("    Deployed at:", await accessGovernor.getAddress());
    });

    it("Should deploy AuditTrail", async function () {
      const AuditTrail = await hre.ethers.getContractFactory("AuditTrail");
      const auditTrail = await AuditTrail.deploy();
      await auditTrail.waitForDeployment();
      
      expect(await auditTrail.getAddress()).to.be.properAddress;
      console.log("    Deployed at:", await auditTrail.getAddress());
    });
  });

  describe("Phase 2: System Adapters", function () {
    let coreAddresses;
    
    before(async function () {
      const SovereignIdentity = await hre.ethers.getContractFactory("SovereignIdentity");
      const sovereignIdentity = await SovereignIdentity.deploy();
      await sovereignIdentity.waitForDeployment();
      
      const AccessGovernor = await hre.ethers.getContractFactory("AccessGovernor");
      const accessGovernor = await AccessGovernor.deploy();
      await accessGovernor.waitForDeployment();
      
      const AuditTrail = await hre.ethers.getContractFactory("AuditTrail");
      const auditTrail = await AuditTrail.deploy();
      await auditTrail.waitForDeployment();
      
      coreAddresses = {
        sovereignIdentity: await sovereignIdentity.getAddress(),
        accessGovernor: await accessGovernor.getAddress(),
        auditTrail: await auditTrail.getAddress()
      };
    });

    it("Should deploy TholosAdapter", async function () {
      const TholosAdapter = await hre.ethers.getContractFactory("TholosAdapter");
      const tholosAdapter = await TholosAdapter.deploy(
        coreAddresses.sovereignIdentity,
        coreAddresses.accessGovernor,
        coreAddresses.auditTrail
      );
      await tholosAdapter.waitForDeployment();
      
      expect(await tholosAdapter.getAddress()).to.be.properAddress;
      console.log("    Deployed at:", await tholosAdapter.getAddress());
    });

    it("Should deploy HarmonicAdapter", async function () {
      const HarmonicAdapter = await hre.ethers.getContractFactory("HarmonicAdapter");
      const harmonicAdapter = await HarmonicAdapter.deploy(
        coreAddresses.sovereignIdentity,
        coreAddresses.accessGovernor,
        coreAddresses.auditTrail
      );
      await harmonicAdapter.waitForDeployment();
      
      expect(await harmonicAdapter.getAddress()).to.be.properAddress;
      console.log("    Deployed at:", await harmonicAdapter.getAddress());
    });

    it("Should deploy TerratoneAdapter", async function () {
      const TerratoneAdapter = await hre.ethers.getContractFactory("TerratoneAdapter");
      const terratoneAdapter = await TerratoneAdapter.deploy(
        coreAddresses.sovereignIdentity,
        coreAddresses.accessGovernor,
        coreAddresses.auditTrail
      );
      await terratoneAdapter.waitForDeployment();
      
      expect(await terratoneAdapter.getAddress()).to.be.properAddress;
      console.log("    Deployed at:", await terratoneAdapter.getAddress());
    });

    it("Should deploy SofieOSAdapter", async function () {
      const SofieOSAdapter = await hre.ethers.getContractFactory("SofieOSAdapter");
      const sofieOSAdapter = await SofieOSAdapter.deploy(
        coreAddresses.sovereignIdentity,
        coreAddresses.accessGovernor,
        coreAddresses.auditTrail
      );
      await sofieOSAdapter.waitForDeployment();
      
      expect(await sofieOSAdapter.getAddress()).to.be.properAddress;
      console.log("    Deployed at:", await sofieOSAdapter.getAddress());
    });

    it("Should deploy LlamaAdapter", async function () {
      const LlamaAdapter = await hre.ethers.getContractFactory("LlamaAdapter");
      const llamaAdapter = await LlamaAdapter.deploy(
        coreAddresses.sovereignIdentity,
        coreAddresses.accessGovernor,
        coreAddresses.auditTrail
      );
      await llamaAdapter.waitForDeployment();
      
      expect(await llamaAdapter.getAddress()).to.be.properAddress;
      console.log("    Deployed at:", await llamaAdapter.getAddress());
    });

    it("Should deploy MapAdapter", async function () {
      const MapAdapter = await hre.ethers.getContractFactory("MapAdapter");
      const mapAdapter = await MapAdapter.deploy(
        coreAddresses.sovereignIdentity,
        coreAddresses.accessGovernor,
        coreAddresses.auditTrail
      );
      await mapAdapter.waitForDeployment();
      
      expect(await mapAdapter.getAddress()).to.be.properAddress;
      console.log("    Deployed at:", await mapAdapter.getAddress());
    });
  });

  describe("Phase 3: PoA Consensus", function () {
    it("Should deploy PoAConsensus", async function () {
      const SovereignIdentity = await hre.ethers.getContractFactory("SovereignIdentity");
      const sovereignIdentity = await SovereignIdentity.deploy();
      await sovereignIdentity.waitForDeployment();
      
      const AuditTrail = await hre.ethers.getContractFactory("AuditTrail");
      const auditTrail = await AuditTrail.deploy();
      await auditTrail.waitForDeployment();
      
      const PoAConsensus = await hre.ethers.getContractFactory("PoAConsensus");
      const poaConsensus = await PoAConsensus.deploy(
        await sovereignIdentity.getAddress(),
        await auditTrail.getAddress()
      );
      await poaConsensus.waitForDeployment();
      
      expect(await poaConsensus.getAddress()).to.be.properAddress;
      console.log("    Deployed at:", await poaConsensus.getAddress());
    });
  });

  describe("Phase 4-6: Integration Tests", function () {
    it("Should perform full system deployment and integration", async function () {
      // Deploy core
      const SovereignIdentity = await hre.ethers.getContractFactory("SovereignIdentity");
      const sovereignIdentity = await SovereignIdentity.deploy();
      await sovereignIdentity.waitForDeployment();
      
      const AccessGovernor = await hre.ethers.getContractFactory("AccessGovernor");
      const accessGovernor = await AccessGovernor.deploy();
      await accessGovernor.waitForDeployment();
      
      const AuditTrail = await hre.ethers.getContractFactory("AuditTrail");
      const auditTrail = await AuditTrail.deploy();
      await auditTrail.waitForDeployment();
      
      const si = await sovereignIdentity.getAddress();
      const ag = await accessGovernor.getAddress();
      const at = await auditTrail.getAddress();
      
      // Deploy adapters
      const adapters = {};
      
      const TholosAdapter = await hre.ethers.getContractFactory("TholosAdapter");
      adapters.tholos = await TholosAdapter.deploy(si, ag, at);
      await adapters.tholos.waitForDeployment();
      
      const HarmonicAdapter = await hre.ethers.getContractFactory("HarmonicAdapter");
      adapters.harmonic = await HarmonicAdapter.deploy(si, ag, at);
      await adapters.harmonic.waitForDeployment();
      
      const TerratoneAdapter = await hre.ethers.getContractFactory("TerratoneAdapter");
      adapters.terratone = await TerratoneAdapter.deploy(si, ag, at);
      await adapters.terratone.waitForDeployment();
      
      const SofieOSAdapter = await hre.ethers.getContractFactory("SofieOSAdapter");
      adapters.sofie = await SofieOSAdapter.deploy(si, ag, at);
      await adapters.sofie.waitForDeployment();
      
      const LlamaAdapter = await hre.ethers.getContractFactory("LlamaAdapter");
      adapters.llama = await LlamaAdapter.deploy(si, ag, at);
      await adapters.llama.waitForDeployment();
      
      const MapAdapter = await hre.ethers.getContractFactory("MapAdapter");
      adapters.map = await MapAdapter.deploy(si, ag, at);
      await adapters.map.waitForDeployment();
      
      // Deploy PoA
      const PoAConsensus = await hre.ethers.getContractFactory("PoAConsensus");
      const poaConsensus = await PoAConsensus.deploy(si, at);
      await poaConsensus.waitForDeployment();
      
      // Verify all addresses
      console.log("    Core Contracts:");
      console.log(`      SovereignIdentity: ${si}`);
      console.log(`      AccessGovernor: ${ag}`);
      console.log(`      AuditTrail: ${at}`);
      console.log("    Adapters:");
      for (const [name, contract] of Object.entries(adapters)) {
        const addr = await contract.getAddress();
        console.log(`      ${name}: ${addr}`);
      }
      console.log(`    PoAConsensus: ${await poaConsensus.getAddress()}`);
      
      // Test mint identity
      const identityHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("test@terracare.earth"));
      const publicKey = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("pk"));
      await sovereignIdentity.connect(user).mintIdentity(identityHash, publicKey);
      expect(await sovereignIdentity.hasIdentity(user.address)).to.be.true;
      console.log("    ✓ Identity minted");
      
      // Test validator registration
      const valHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("validator"));
      await poaConsensus.registerValidator(
        deployer.address,
        valHash,
        "Test Validator",
        "http://test.node",
        { value: hre.ethers.parseEther("1") }
      );
      
      const validator = await poaConsensus.getValidator(deployer.address);
      expect(validator.status).to.equal(1); // Active
      console.log("    ✓ Validator registered");
      
      // Test device certification (deployer is initial certifier)
      await adapters.harmonic.addCertifier(deployer.address);
      const deviceHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("device1"));
      await adapters.harmonic.certifyDevice(deviceHash, 0, 2, 0, hre.ethers.ZeroHash);
      expect(await adapters.harmonic.isDeviceCertified(deviceHash)).to.be.true;
      console.log("    ✓ Device certified");
      
      // Test Llama adapter (deployer is initial operator)
      const modelHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("model1"));
      await adapters.llama.registerModel(modelHash, "Test Model", 1, hre.ethers.ZeroHash);
      // Note: approveModel requires accessGovernor or sovereignIdentity
      console.log("    ✓ AI Model registered");
      
      console.log("    ✓✓✓ Integration test complete");
    });
  });
});
