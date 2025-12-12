// MultiChainConfig.js
// Example config and stub logic for multi-chain support

export const MultiChainConfig = {
  chains: [
    {
      id: 'terracare',
      name: 'Terracare Chain',
      rpcUrl: process.env.TERRACARE_RPC || 'https://rpc.terracare.org',
      contracts: {
        IdentityRegistry: process.env.TERRACARE_IDENTITY_REGISTRY || '',
        AccessControl: process.env.TERRACARE_ACCESS_CONTROL || '',
        RecordRegistry: process.env.TERRACARE_RECORD_REGISTRY || '',
        AuditLog: process.env.TERRACARE_AUDIT_LOG || ''
      }
    },
    {
      id: 'ethereum',
      name: 'Ethereum Mainnet',
      rpcUrl: process.env.ETHEREUM_RPC || 'https://mainnet.infura.io/v3/YOUR_INFURA_KEY',
      contracts: {
        IdentityRegistry: process.env.ETHEREUM_IDENTITY_REGISTRY || '',
        AccessControl: process.env.ETHEREUM_ACCESS_CONTROL || '',
        RecordRegistry: process.env.ETHEREUM_RECORD_REGISTRY || '',
        AuditLog: process.env.ETHEREUM_AUDIT_LOG || ''
      }
    },
    {
      id: 'polygon',
      name: 'Polygon',
      rpcUrl: process.env.POLYGON_RPC || 'https://polygon-rpc.com',
      contracts: {
        IdentityRegistry: process.env.POLYGON_IDENTITY_REGISTRY || '',
        AccessControl: process.env.POLYGON_ACCESS_CONTROL || '',
        RecordRegistry: process.env.POLYGON_RECORD_REGISTRY || '',
        AuditLog: process.env.POLYGON_AUDIT_LOG || ''
      }
    }
  ],
  listChains() {
    return this.chains.map(c => ({ id: c.id, name: c.name }));
  },
  async getChainStatus(chainId) {
    const chain = this.chains.find(c => c.id === chainId);
    if (!chain) throw new Error('Chain not found');
    // In real code, ping the RPC or check contract status
    return { id: chain.id, name: chain.name, status: 'ok' };
  },

  // --- Ethers.js Contract Adapter (Stub) ---
  getProvider(chainId) {
    const { ethers } = require('ethers');
    const chain = this.chains.find(c => c.id === chainId);
    if (!chain) throw new Error('Chain not found');
    return new ethers.JsonRpcProvider(chain.rpcUrl);
  },

  getContract(chainId, contractName, abi, addressOverride) {
    const provider = this.getProvider(chainId);
    const chain = this.chains.find(c => c.id === chainId);
    const address = addressOverride || (chain.contracts && chain.contracts[contractName]);
    if (!address) throw new Error('Contract address not set');
    return new (require('ethers').Contract)(address, abi, provider);
  },

  // ABIs for contracts (replace with actual ABIs or import from JSON)
  abis: {
    IdentityRegistry: require('../contracts/abi/IdentityRegistry.json'),
    AccessControl: require('../contracts/abi/AccessControl.json'),
    RecordRegistry: require('../contracts/abi/RecordRegistry.json'),
    AuditLog: require('../contracts/abi/AuditLog.json')
  }
};
