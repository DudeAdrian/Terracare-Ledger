// MultiChainConfig.ts
// Configuration for supported blockchains

export interface ChainConfig {
  name: string;
  rpcUrl: string;
  chainId: number;
  contracts: {
    identityRegistry: string;
    accessControl: string;
    auditLog: string;
    recordRegistry: string;
  };
}

export const CHAINS: ChainConfig[] = [
  {
    name: 'Terracare',
    rpcUrl: 'https://terracare-node.example.com',
    chainId: 1337,
    contracts: {
      identityRegistry: '', // Fill in deployed address
      accessControl: '',
      auditLog: '',
      recordRegistry: '',
    },
  },
  {
    name: 'Ethereum',
    rpcUrl: 'https://mainnet.infura.io/v3/YOUR_INFURA_KEY',
    chainId: 1,
    contracts: {
      identityRegistry: '',
      accessControl: '',
      auditLog: '',
      recordRegistry: '',
    },
  },
  // Add more chains as needed
];
