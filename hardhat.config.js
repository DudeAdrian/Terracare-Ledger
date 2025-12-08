require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const {
  TERRACARE_RPC_URL = "http://localhost:8545",
  DEPLOYER_PRIVATE_KEY,
  TERRACARE_CHAIN_ID = 1337,
} = process.env;

/**
 * Terracare Ledger Hardhat config
 * - PoA-friendly (set gasPrice to 0 if your client permits)
 * - Tokenless, private network
 */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: { enabled: true, runs: 500 }
    }
  },
  networks: {
    hardhat: {
      chainId: 1337,
    },
    terracare: {
      url: TERRACARE_RPC_URL,
      chainId: Number(TERRACARE_CHAIN_ID),
      accounts: DEPLOYER_PRIVATE_KEY ? [DEPLOYER_PRIVATE_KEY] : [],
      gasPrice: 0,
    }
  },
  etherscan: {
    apiKey: "" // not used for private networks
  }
};
