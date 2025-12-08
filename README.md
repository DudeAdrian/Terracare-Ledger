# Terracare Ledger
Tokenless, permissioned PoA ledger for Heartware and Sofie-Systems OS.

## Features
- Tokenless (gasPrice=0), private PoA network
- Identity + Access + Record + Audit contracts
- Hashes/pointers only (keep PHI off-chain)
- Hardhat scripts for deploy/test

## Quickstart
```bash
npm install
npm run build
npm run deploy:local      # in-process dev chain
npm run deploy:custom     # uses TERRACARE_RPC_URL
```

## Env
```
TERRACARE_RPC_URL=http://localhost:8545
DEPLOYER_PRIVATE_KEY=0x...
TERRACARE_CHAIN_ID=1337
```

## Contracts
- IdentityRegistry: register roles, activate/deactivate
- AccessControl: patient grants/revokes caregiver access
- RecordRegistry: store data hashes/pointers with versions
- AuditLog: append-only event log

## Notes
- Use IPFS/S3 + AES for encrypted payloads; store hash on-chain
- Run 3–5 validators; set gasPrice=0 on nodes for fee-less ops
- Add org-level allowlists in IdentityRegistry as needed

## Next
- Add API gateway with rate limiting
- Add CI for compile/test
- Add org admin flows
