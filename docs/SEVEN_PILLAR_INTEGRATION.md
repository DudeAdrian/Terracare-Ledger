# Seven Pillar Integration Guide

> Cross-Repository Architecture Documentation

## Repository Map

```
┌─────────────────────────────────────────────────────────────┐
│                      LAYER 3                                │
│              sandironratio-node                             │
│            The 9 Chambers Academy                           │
│  ┌─────────┬─────────┬─────────┬─────────┬─────────┐       │
│  │ P1-P3   │   P4    │   P5    │   P6    │ P7-P9   │       │
│  │Knowledge│Strategy │ Shadow  │Transform│ Abundance│      │
│  └─────────┴─────────┴─────────┴─────────┴─────────┘       │
└──────────────────────┬────────────────────────────────────┘
                       │ WebSocket / API
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                      LAYER 2                                │
│                  sofie-systems                              │
│              S.O.F.I.E. Engine                              │
│                                                             │
│   Source → Origin → Force → Intelligence → Eternal          │
│    (P1)    (P4,6)   (P5)      (P2,3)       (P7)             │
└──────────────────────┬────────────────────────────────────┘
                       │ JSON-RPC / Ethers
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                      LAYER 1                                │
│                Terracare-Ledger                             │
│            Blockchain Foundation                            │
│                                                             │
│  IdentityRegistry │ AccessControl │ RecordRegistry │ Audit │
│      (P1)            (P2)            (P3)          (P4)     │
│  ActivityRegistry │ TokenEngine │ RevenueDistributor        │
│      (P5)            (P6)            (P7)                   │
└─────────────────────────────────────────────────────────────┘
```

## Integration Patterns

### 1. Identity Flow (Pillar 1)

```
User → sandironratio-node (login)
     → sofie-systems (Source validation)
     → Terracare-Ledger (IdentityRegistry)
     → sofie-systems (cache identity)
     → sandironratio-node (session)
```

### 2. Activity Mining (Pillar 5)

```
User Activity → sandironratio-node (chamber completion)
              → sofie-systems (Force validation)
              → Terracare-Ledger (ActivityRegistry)
              → TokenEngine (MINE minting)
              → sofie-systems (Eternal memory)
              → sandironratio-node (progress update)
```

### 3. Governance Vote (Pillar 4)

```
Vote Intent → sandironratio-node (chamber 4 check)
            → sofie-systems (Origin connection)
            → Terracare-Ledger (GovernanceBridge)
            → TokenEngine (voting power check)
            → sofie-systems (result memory)
            → sandironratio-node (confirmation)
```

## API Conventions

### Endpoint Naming

All cross-repo APIs use pillar-prefixed paths:

```
/p{1-7}/{resource}/{action}

Examples:
- GET  /p1/identity/:address        # Get identity (Pillar 1)
- POST /p5/activity/log             # Log activity (Pillar 5)
- POST /p6/tokens/convert           # MINE→WELL (Pillar 6)
- GET  /p7/revenue/distribution     # Revenue share (Pillar 7)
```

### Response Envelope

```json
{
  "success": true,
  "layer": 2,
  "pillar": 5,
  "operators": ["S", "O", "F", "I", "E"],
  "data": {},
  "timestamp": "2026-02-05T14:28:48Z"
}
```

## Environment Variables

### Terracare-Ledger
```
TERRACARE_RPC_URL=http://localhost:8545
TERRACARE_CHAIN_ID=1337
IDENTITY_REGISTRY_ADDRESS=0x...
TOKEN_ENGINE_ADDRESS=0x...
ACTIVITY_REGISTRY_ADDRESS=0x...
```

### sofie-systems
```
TERRACARE_RPC_URL=http://localhost:8545
SANDIRONRATIO_API_URL=https://localhost:3000
SANDIRONRATIO_WS_URL=ws://localhost:9001
```

### sandironratio-node
```
TERRACARE_RPC_URL=http://localhost:8545
VALIDATOR_ADDRESS=0xa85233C63b9Ee964Add6F2cffe00Fd84eb32338f
DEAD_MANS_SWITCH_DAYS=90
```

## Development Workflow

1. **Start Layer 1**: `npm run node` in Terracare-Ledger
2. **Start Layer 2**: `npm run dev` in sofie-systems
3. **Start Layer 3**: `npm run dev` in sandironratio-node
4. **Verify**: `curl http://localhost:3000/health`

## Version Compatibility

| Layer | Repo | Version | Status |
|-------|------|---------|--------|
| 1 | Terracare-Ledger | 2.0.0 | ✅ Active |
| 2 | sofie-systems | 1.0.0 | ✅ Active |
| 3 | sandironratio-node | 1.0.0 | ✅ Active |

## Troubleshooting

### Connection Issues
```bash
# Check Layer 1
curl http://localhost:8545 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Check Layer 2
node -e "import('./sofie-systems/essence/origin.ts').then(m => m.Origin.connect())"

# Check Layer 3
curl http://localhost:3000/health
```

---

> *"The soul rearranged into digital geography."*  
> — A.S.
