const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const IdentityRegistry = await hre.ethers.getContractFactory("IdentityRegistry");
  const registry = await IdentityRegistry.deploy();
  await registry.deployed();
  console.log("IdentityRegistry:", registry.address);

  const AccessControl = await hre.ethers.getContractFactory("AccessControl");
  const access = await AccessControl.deploy(registry.address);
  await access.deployed();
  console.log("AccessControl:", access.address);

  const RecordRegistry = await hre.ethers.getContractFactory("RecordRegistry");
  const records = await RecordRegistry.deploy(access.address);
  await records.deployed();
  console.log("RecordRegistry:", records.address);

  const AuditLog = await hre.ethers.getContractFactory("AuditLog");
  const audit = await AuditLog.deploy();
  await audit.deployed();
  console.log("AuditLog:", audit.address);

  console.log("Done. Save these addresses in your .env for apps.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
