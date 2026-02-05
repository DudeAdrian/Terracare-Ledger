# TerraCare Ledger v2.0 - Participation Layer

## Overview

The Participation Layer transforms TerraCare from a tokenless PoA health record system into a **self-sustaining cooperative economic engine**. Users earn MINE tokens through health activities, which can be converted to WELL utility tokens or used for governance.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TERRACARE LEDGER v2.0                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   MINE Token │  │   WELL Token │  │   Activity   │  │   Revenue    │    │
│  │   (Earned)   │  │  (Utility)   │  │   Registry   │  │  Distributor │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
│         │                 │                 │                 │            │
│         └─────────────────┴─────────────────┴─────────────────┘            │
│                               │                                            │
│                    ┌──────────▼──────────┐                                 │
│                    │   TokenEngine.sol   │                                 │
│                    └──────────┬──────────┘                                 │
│                               │                                            │
│  ┌────────────────────────────┼────────────────────────────────────────┐  │
│  │                            │         IDENTITY LAYER                 │  │
│  │  ┌──────────────┐  ┌───────▼───────┐  ┌──────────────┐              │  │
│  │  │   Identity   │  │    Access     │  │    Record    │              │  │
│  │  │   Registry   │◄─┤    Control    │◄─┤   Registry   │              │  │
│  │  └──────────────┘  └───────────────┘  └──────────────┘              │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Dual-Token System

### MINE Token (Participation Token)

| Attribute | Value |
|-----------|-------|
| **Name** | TerraCare MINE |
| **Symbol** | MINE |
| **Type** | Earned only (no purchase) |
| **Earning Rate** | 10 MINE per value point |
| **Transferability** | Initially disabled, governance-enabled |
| **Use Cases** | Governance voting, cooperative membership, premium access |

**Earning Paths:**

1. **Biometric Streaming** (5 points/stream)
   - Continuous health data from wearables
   - Quality-based scoring
   - Max 5 streams/day = 25 points

2. **Therapy Completion** (20 points/session)
   - Validated by licensed caregiver
   - Based on session duration and outcomes

3. **Data Validation** (15 points/contribution)
   - Anonymized health data for research
   - Uniqueness scoring

4. **Referrals** (25 points/referee)
   - New active user joins platform
   - Referee must complete onboarding

5. **Survey Completion** (10 points/survey)
   - Health surveys and feedback

6. **Preventive Care** (30 points/action)
   - Proactive health actions
   - Vaccinations, screenings, etc.

### WELL Token (Utility Token)

| Attribute | Value |
|-----------|-------|
| **Name** | TerraCare WELL |
| **Symbol** | WELL |
| **Type** | Bought or converted from MINE |
| **Conversion** | 100 MINE = 1 WELL |
| **Purchase** | Available via Stripe/NDIS integration |
| **Use Cases** | Premium features, data marketplace, service payments |

**Conversion Mechanics:**
- MINE is **burned** during conversion
- WELL is **minted** to user
- Creates deflationary pressure on MINE
- Rewards long-term participants

## Anti-Gaming Mechanisms

### Daily Rate Limits

```solidity
uint256 public constant DAILY_POINTS_CAP = 100; // Max per user per day
```

| Activity Type | Base Points | Daily Limit |
|---------------|-------------|-------------|
| Biometric Stream | 5 | 5 streams |
| Therapy Completion | 20 | 3 sessions |
| Data Validation | 15 | 3 contributions |
| Referrals | 25 | 2 referees |
| Surveys | 10 | 2 surveys |
| Preventive Care | 30 | 1 action |

### Sybil Resistance

1. **Identity Verification**: KYC for cooperative membership
2. **Device Fingerprinting**: Wearable device registration
3. **Behavioral Analysis**: AI detects suspicious patterns
4. **Social Graph Analysis**: Network-based fraud detection

### AI Oracle Validation

```
Value Score = Σ(quality_metrics × weights)

Biometric:
- Data completeness (30%)
- Signal quality (40%)
- Timestamp consistency (20%)
- Device trust (10%)

Therapy:
- Session duration (30%)
- Adherence score (40%)
- Outcome metrics (30%)

Data Contribution:
- Data size (20%)
- Anonymization level (30%)
- Uniqueness score (50%)
```

## Cooperative Economic Model

### Revenue Split

All platform revenue (Stripe payments, NDIS funding, enterprise contracts) is distributed:

```
┌────────────────────────────────────────────────────────┐
│                    Revenue Pool                        │
└──────────────┬─────────────────────────────────────────┘
               │
   ┌───────────┼───────────┬──────────────┬────────────┐
   ▼           ▼           ▼              ▼            ▼
┌──────┐   ┌──────┐   ┌──────────┐   ┌────────┐   ┌────────┐
│ 30%  │   │ 20%  │   │   40%    │   │  10%   │   │   0%   │
│Users │   │SEAL  │   │Operations│   │Reserve │   │Profit  │
│Buyback│   │Repay │   │          │   │        │   │        │
└──────┘   └──────┘   └──────────┘   └────────┘   └────────┘
```

### SEAL Investment Structure

**SEAL** (Sustainable Equity for Autonomous Legacies) - A capped-return investment model:

| Term | Value |
|------|-------|
| **Initial Investment** | $750,000 |
| **Repayment Cap** | 3-5x initial |
| **Revenue Share** | 20% until cap reached |
| **Ownership** | Zero equity - pure repayment |
| **Cap Enforcement** | Automatic via smart contract |

**Example Scenarios:**

| Revenue Year | Annual Revenue | Investor Share | Cumulative | Cap Status |
|--------------|----------------|----------------|------------|------------|
| 1 | $500K | $100K | $100K | Active |
| 2 | $1M | $200K | $300K | Active |
| 3 | $2M | $400K | $700K | Active |
| 4 | $3M | $800K → $550K | $1.25M (3x) | **Capped** |
| 5 | $5M | $0 | $1.25M | Retired |

After cap reached, the 20% investor share is redirected to user buybacks.

## Governance Roadmap

### Phase 1: PoA (Months 0-18)

```
┌─────────────────────────────────────────────────────┐
│  VALIDATORS                                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐             │
│  │ Hospital│  │  NDIS   │  │ Research│             │
│  │   A     │  │  Org    │  │  Inst   │             │
│  └────┬────┘  └────┬────┘  └────┬────┘             │
│       └─────────────┼─────────────┘                  │
│                     ▼                                │
│              ┌────────────┐                          │
│              │ Governance │                          │
│              │   Bridge   │                          │
│              └────────────┘                          │
└─────────────────────────────────────────────────────┘
```

- Validators: Healthcare institutions, NDIS organizations
- Proposal threshold: Validator status only
- Voting: Multi-sig validator consensus
- Focus: Platform stability, security audits

### Phase 2: Transition (Months 18-24)

- Gradual MINE-holder voting rights
- 50/50 validator/token-holder weighting
- Proposal threshold: 1,000 staked MINE
- Voting period: 7 days
- Timelock: 2 days

### Phase 3: Cooperative (Month 24+)

```
┌─────────────────────────────────────────────────────┐
│  MINE TOKEN HOLDERS                                 │
│                                                     │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐  │
│  │ Patient │ │ Caregiver│ │ Research│ │  Admin  │  │
│  │    A    │ │    B    │ │    C    │ │    D    │  │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘  │
│       └───────────┴───────────┴───────────┘       │
│                   │                                 │
│                   ▼                                 │
│            ┌────────────┐                          │
│            │ Governance │                          │
│            │   Bridge   │                          │
│            └────────────┘                          │
└─────────────────────────────────────────────────────┘
```

- Full cooperative ownership
- 1 MINE = 1 vote (with staking multiplier)
- Validators become operational nodes only
- Revenue splits adjustable by governance

## Membership Tiers

| Tier | MINE Required | Benefits |
|------|---------------|----------|
| **Basic** | 0 | Core health records, basic access |
| **Premium** | 500 | Priority support, analytics dashboard |
| **Enterprise** | 5,000 | API access, custom integrations |
| **Cooperative** | 1,000 | Governance voting, dividend rights |

## Gas Economics

### Core Operations (gasPrice = 0)

- Identity registration
- Access control (grant/revoke)
- Record updates
- Audit logging

### Participation Operations (MINE as gas)

- Activity recording (subsidized by backend)
- Token conversion (user pays MINE)
- Governance voting (staked MINE)
- Revenue distribution (protocol pays)

**Subsidization Model:**
```
User Activity → Backend Oracle → Contract Call (gasPrice=0)
                                    ↓
                        Backend wallet pays gas
                        (no cost to user)
```

## API Reference

### Activity Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/activity/biometric` | JWT | Submit biometric stream |
| POST | `/api/activity/therapy` | JWT + Role | Mark therapy complete |
| GET | `/api/user/balance/:id` | JWT | Get MINE/WELL balances |
| GET | `/api/user/daily-status/:id` | JWT | Get daily points status |

### Revenue Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/revenue/webhook` | Webhook | Stripe/NDIS payments |
| GET | `/api/revenue/distribution` | JWT + Admin | Revenue stats |
| POST | `/api/revenue/sell-well` | JWT | Sell WELL for ETH |

### Governance Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/governance/propose` | JWT + 1k MINE | Create proposal |
| POST | `/api/governance/vote` | JWT + Stake | Cast vote |
| GET | `/api/governance/proposals` | Public | List proposals |
| GET | `/api/governance/phase` | Public | Current phase |

## Security Considerations

### Smart Contract Security

- **Audits**: Required before mainnet deployment
- **Timelock**: 2-day delay on governance actions
- **Multi-sig**: Critical functions require 2+ validators
- **Emergency Pause**: Circuit breaker for critical issues

### Oracle Security

- **Key Management**: HSM for AI signer keys
- **Rate Limiting**: Max 100 requests/minute per oracle
- **Consensus**: Multiple oracle signatures for high-value actions
- **Slashing**: Malicious oracles lose stake

### Economic Security

- **Flash Loan Protection**: Time-weighted average for pricing
- **Reentrancy Guards**: All external calls protected
- **Integer Overflow**: Solidity 0.8+ built-in protection
- **Front-running**: Commit-reveal scheme for governance

## Deployment Checklist

### Pre-Deployment

- [ ] Smart contract audit completed
- [ ] Testnet deployment verified
- [ ] Oracle infrastructure ready
- [ ] Backend services deployed
- [ ] Monitoring dashboards configured

### Deployment

- [ ] Deploy TokenEngine
- [ ] Deploy ActivityRegistry
- [ ] Deploy RevenueDistributor
- [ ] Deploy GovernanceBridge
- [ ] Link existing IdentityRegistry
- [ ] Set SEAL investor address and cap
- [ ] Grant oracle roles to backend
- [ ] Verify contracts on explorer

### Post-Deployment

- [ ] Seed initial validators
- [ ] Configure revenue split
- [ ] Test end-to-end workflows
- [ ] Enable activity tracking
- [ ] Start revenue webhooks
- [ ] Monitor for anomalies

## Future Enhancements

1. **Cross-Chain Bridging**: MINE/WELL on L2s
2. **Data Marketplace**: Buy/sell anonymized health data
3. **Insurance Integration**: Premium discounts for activity
4. **Research DAO**: Community-driven health research
5. **Interoperability**: FHIR standard compliance

## Resources

- **Smart Contracts**: `/contracts/*.sol`
- **API Documentation**: `/docs/API.md`
- **Deployment Guide**: `/docs/DEPLOYMENT.md`
- **Test Suite**: `/test/ParticipationLayer.test.js`

---

*Last Updated: 2026-02-05*
*Version: 2.0.0*
