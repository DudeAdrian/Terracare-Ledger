// index.ts
// Entry point for the multi-chain backend API

import express from 'express';
import { CHAINS } from './MultiChainConfig.ts';

const app = express();
app.use(express.json());

// Example: List supported chains
app.get('/api/chains', (req, res) => {
  res.json(CHAINS.map(chain => ({
    name: chain.name,
    chainId: chain.chainId,
    rpcUrl: chain.rpcUrl
  })));
});

// TODO: Add endpoints for identity, access, audit, records (per chain)

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Terracare Ledger API running on port ${PORT}`);
});
