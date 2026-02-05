# Terracare Ledger

> **Layer 1 of the Seven Pillar Architecture** — *Foundation for S.O.F.I.E.*

Tokenless, permissioned PoA ledger for Heartware, Sofie-Systems OS, and sandironratio-node.

[![Seven Pillars](https://img.shields.io/badge/Seven%20Pillars-v1.0.0-blue)](./SEVEN_PILLARS.md)
[![S.O.F.I.E.](https://img.shields.io/badge/S.O.F.I.E.-Origin%20Layer-orange)](./SEVEN_PILLARS.md)

---

## Seven Pillar Mapping

| Pillar | Chamber | Contracts | API Prefix |
|--------|---------|-----------|------------|
| **P1**: Underground Knowledge | 1 - Root Cellar | `IdentityRegistry` | `/p1/identity/*` |
| **P2**: Mental Models | 2 - Mirror Hall | `AccessControl` | `/p2/access/*` |
| **P3**: Reverse Engineering | 3 - Portrait Gallery | `RecordRegistry` | `/p3/records/*` |
| **P4**: Strategic Dominance | 4 - Observatory Tower | `AuditLog`, `GovernanceBridge` | `/p4/governance/*` |
| **P5**: Black Market Tactics | 5 - Midnight Garden | `ActivityRegistry` | `/p5/participation/*` |
| **P6**: Forbidden Frameworks | 6 - Laboratory | `TokenEngine` | `/p6/tokens/*` |
| **P7**: Billionaire Mindset | 7 - Throne Room | `RevenueDistributor` | `/p7/revenue/*` |

---

## Features

- **Tokenless** (gasPrice=0), private PoA network
- **Identity + Access + Record + Audit** contracts
- **Hashes/pointers only** (keep PHI off-chain)
- **Dual-token economics**: MINE (participation) + WELL (utility)
- **Hardhat** scripts for deploy/test

---

## Quickstart

```bash
npm install
npm run build
npm run deploy:local      # in-process dev chain
npm run deploy:custom     # uses TERRACARE_RPC_URL
```

---

## Environment

```
TERRACARE_RPC_URL=http://localhost:8545
DEPLOYER_PRIVATE_KEY=0x...
TERRACARE_CHAIN_ID=1337
```

---

## Contracts

### Core v1.0 (Pillars 1-4)
| Contract | Pillar | Purpose |
|----------|--------|---------|
| `IdentityRegistry` | P1 | Register roles, activate/deactivate |
| `AccessControl` | P2 | Patient grants/revokes caregiver access |
| `RecordRegistry` | P3 | Store data hashes/pointers with versions |
| `AuditLog` | P4 | Append-only event log |

### Participation v2.0 (Pillars 5-7)
| Contract | Pillar | Purpose |
|----------|--------|---------|
| `ActivityRegistry` | P5 | Log health activities with anti-gaming |
| `TokenEngine` | P6 | Dual-token system (MINE/WELL) |
| `RevenueDistributor` | P7 | Cooperative revenue sharing |
| `GovernanceBridge` | P4 | Timelock transition to governance |

---

## S.O.F.I.E. Integration

Terracare provides the **Origin (O)** layer for S.O.F.I.E.:

```
S.O.F.I.E. Operators:
├── Source (S) → sofie-systems
├── Origin (O) → **Terracare-Ledger** ← YOU ARE HERE
├── Force (F) → sandironratio-node
├── Intelligence (I) → sandironratio-node
└── Eternal (E) → sofie-systems
```

See [SEVEN_PILLARS.md](./SEVEN_PILLARS.md) for complete architecture.

---

## API Structure

All endpoints follow the pillar convention:

```
POST /p1/identity/register       # Pillar 1: Identity
POST /p2/access/grant            # Pillar 2: Access
GET  /p3/records/:id             # Pillar 3: Records
GET  /p4/audit/events            # Pillar 4: Audit
POST /p5/participation/activity  # Pillar 5: Activity
POST /p6/tokens/convert          # Pillar 6: Tokens
GET  /p7/revenue/distribution    # Pillar 7: Revenue
```

---

## Notes

- Use IPFS/S3 + AES for encrypted payloads; store hash on-chain
- Run 3–5 validators; set gasPrice=0 on nodes for fee-less ops
- Add org-level allowlists in IdentityRegistry as needed

---

## Related Repositories

| Repo | Layer | Role |
|------|-------|------|
| [sofie-systems](https://github.com/DudeAdrian/sofie-systems) | Layer 2 | S.O.F.I.E. core engine |
| [sandironratio-node](https://github.com/DudeAdrian/sandironratio-node) | Layer 3 | 9 Chambers Academy |

---

## Next

- [ ] Add API gateway with rate limiting
- [ ] Add CI for compile/test
- [ ] Add org admin flows
- [ ] Complete cross-repo bridge

---

> *"The Dude abides."*  
> — A.S.
