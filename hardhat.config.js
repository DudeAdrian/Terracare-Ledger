require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const {
  TERRACARE_RPC_URL = "http://localhost:8545",
  DEPLOYER_PRIVATE_KEY,
  TERRACARE_CHAIN_ID = 1337,
  TERRACARE_MINE_TOKEN_ADDRESS,
} = process.env;

/**
 * TerraCare Ledger Hardhat config v2.0
 * - PoA-friendly (set gasPrice to 0 if your client permits)
 * - Participation Layer: MINE/WELL dual-token system
 * - Gas economics: 0 for core operations, MINE for participation
 */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: { enabled: true, runs: 500 },
      viaIR: true,
    },
  },
  networks: {
    hardhat: {
      chainId: 1337,
      forking: process.env.FORK_URL ? {
        url: process.env.FORK_URL,
      } : undefined,
      // Simulate gasPrice=0 behavior for testing
      initialBaseFeePerGas: 0,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 1337,
      accounts: DEPLOYER_PRIVATE_KEY ? [DEPLOYER_PRIVATE_KEY] : undefined,
      gasPrice: 0,
    },
    terracare: {
      url: TERRACARE_RPC_URL,
      chainId: Number(TERRACARE_CHAIN_ID),
      accounts: DEPLOYER_PRIVATE_KEY ? [DEPLOYER_PRIVATE_KEY] : [],
      gasPrice: 0, // PoA: validators don't charge gas
    },
    // MINE token as gas token network (for participation operations)
    terracare_participation: {
      url: TERRACARE_RPC_URL,
      chainId: Number(TERRACARE_CHAIN_ID),
      accounts: DEPLOYER_PRIVATE_KEY ? [DEPLOYER_PRIVATE_KEY] : [],
      // Participation operations use MINE as gas
      // Backend subsidizes for users
      gasPrice: 0, // Still 0 gas, but MINE consumed by contracts
    },
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      goerli: process.env.ETHERSCAN_API_KEY || "",
      sepolia: process.env.ETHERSCAN_API_KEY || "",
    },
    customChains: [
      {
        network: "terracare",
        chainId: Number(TERRACARE_CHAIN_ID),
        urls: {
          apiURL: `${TERRACARE_RPC_URL}/api`,
          browserURL: TERRACARE_RPC_URL,
        },
      },
    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 40000,
  },
  // Custom configuration for TerraCare Participation Layer
  terracare: {
    // Token addresses (populated after deployment)
    tokens: {
      MINE: TERRACARE_MINE_TOKEN_ADDRESS || "",
      WELL: process.env.TERRACARE_WELL_TOKEN_ADDRESS || "",
    },
    // Gas configuration
    gas: {
      // Core operations (identity, access, records, audit)
      coreOperations: {
        gasPrice: 0,
        gasLimit: 200000,
      },
      // Participation operations (activity, token conversion)
      participationOperations: {
        gasPrice: 0, // Still 0, but MINE tokens consumed
        gasLimit: 300000,
      },
    },
    // Rate limits
    rateLimits: {
      dailyPointsCap: 100, // Max 100 points per user per day
      activityCooldown: 60, // 60 seconds between activities
    },
    // Economic parameters
    economics: {
      minePerValuePoint: 10, // 10 MINE per value point
      conversionRatio: 100, // 100 MINE = 1 WELL
      membershipThreshold: 1000, // 1000 MINE for cooperative membership
      proposalThreshold: 1000, // 1000 staked MINE for proposals
    },
  },
};
