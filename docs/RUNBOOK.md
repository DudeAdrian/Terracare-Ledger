# Terracare Ledger Runbook (Tokenless PoA)

## Prereqs
- Node 18+
- npm
- (Optional) Docker/VMs for validators

## Install
```bash
npm install
```

## Compile & Test
```bash
npm run build
npm test
```

## Networks
- `hardhat`: local dev chain (ephemeral)
- `terracare`: your private PoA endpoint (`TERRACARE_RPC_URL`)

## Config (.env)
```
TERRACARE_RPC_URL=http://localhost:8545
DEPLOYER_PRIVATE_KEY=0x...
TERRACARE_CHAIN_ID=1337
```

## Deploy
```bash
# Local in-process
npm run deploy:local

# Custom PoA
npm run deploy:custom
```

## Contracts (addresses after deploy)
- IdentityRegistry
- AccessControl
- RecordRegistry
- AuditLog

## Integration Notes
- Set `gasPrice=0` on your PoA nodes for tokenless operation.
- Keep PHI off-chain; store hashes/pointers only.
- Use AES + IPFS/S3 for encrypted payloads; put hash on-chain.

## Validator Guidance
- 3–5 validators (IBFT/Clique) for resilience.
- Protect keys (HSM/KMS if possible).
- Monitor block time, peer count, and errors (Prometheus/Grafana).

## Next Steps
- Add org-level allowlists in IdentityRegistry.
- Add role checks in AccessControl if you need stricter policies.
- Add API gateway with rate limiting for app traffic.
