# Terracare Ledger User Guide

## Overview
Terracare Ledger is a secure, modular, multi-chain ledger for wellness, sustainability, and conscious living. It supports integration with Sofie-Systems and Heartware, and is designed for extensibility, privacy, and ease of use.

---

## Table of Contents
1. [Getting Started](#getting-started)
2. [Architecture Overview](#architecture-overview)
3. [Smart Contracts](#smart-contracts)
4. [Backend API](#backend-api)
5. [Database & Analytics](#database--analytics)
6. [UI Integration](#ui-integration)
7. [Security & Privacy](#security--privacy)
8. [Participation Layer v2.0](#participation-layer-v20)
9. [Troubleshooting](#troubleshooting)
10. [FAQ](#faq)

---

## Getting Started

### Prerequisites
- Node.js (v18+ recommended)
- npm
- PostgreSQL (for analytics/user settings)
- Git

### Clone the Repository
```bash
git clone https://github.com/DudeAdrian/Terracare-Ledger.git
cd Terracare-Ledger
```

### Install Dependencies
```bash
cd backend
npm install
```

### Configure Environment
Copy `.env.example` to `.env` and fill in your keys and database URL.

### Database Setup
```bash
npx prisma generate
npx prisma migrate dev --name init
```

### Start Backend
```bash
npm run dev
```

---

## Architecture Overview
- **contracts/**: Solidity smart contracts (Identity, Access, Records, Audit, Participation)
- **backend/**: Node.js/Express API, multi-chain, modular
- **frontend/**: (planned) UI extension for Sofie-Systems/Heartware
- **docs/**: Integration and API documentation

---

## Smart Contracts

### Core Contracts (v1.0)
- **IdentityRegistry**: Register and manage user roles
- **AccessControl**: Grant/revoke access to records
- **RecordRegistry**: Store data hashes/pointers (no PHI)
- **AuditLog**: Transparent, append-only event log

### Participation Layer (v2.0)
- **TokenEngine**: Dual-token system (MINE/WELL) for participation economics
- **ActivityRegistry**: Log health activities with anti-gaming rate limits
- **RevenueDistributor**: Cooperative revenue sharing with SEAL investor model
- **GovernanceBridge**: Timelock transition to MINE-holder governance

Deploy contracts using Hardhat scripts in the root directory.

---

## Backend API
- See `backend/README.md` and `docs/UI_INTEGRATION.md` for endpoint details
- See `docs/PARTICIPATION_LAYER.md` for participation API endpoints
- JWT authentication required for sensitive actions
- Multi-chain support: specify `chainId` in requests

---

## Database & Analytics
- User profiles, extension management, and analytics are stored in PostgreSQL
- Prisma ORM is used for database access

---

## UI Integration
- Add a new card/branch in Sofie-Systems/Heartware
- Use API endpoints to fetch and manage ledger data
- See `docs/UI_INTEGRATION.md` for integration patterns

---

## Security & Privacy
- Role-based access control on-chain and in backend
- All sensitive actions require JWT authentication
- Input validation, rate limiting, and secure headers enabled
- No sensitive data stored on-chain (hashes only)
- AI-powered fraud detection for activity validation
- Multi-sig requirements for critical operations

---

## Participation Layer v2.0

### Earning MINE Tokens

Users earn MINE tokens through health engagement:

| Activity | Points | Max/Day | MINE Earned |
|----------|--------|---------|-------------|
| Biometric Streaming | 5 | 5 streams | 250 MINE |
| Therapy Completion | 20 | 3 sessions | 600 MINE |
| Data Contribution | 15 | 3 uploads | 450 MINE |
| Referrals | 25 | 2 referees | 500 MINE |
| Health Surveys | 10 | 2 surveys | 200 MINE |
| Preventive Care | 30 | 1 action | 300 MINE |
| **Daily Cap** | - | - | **1000 MINE** |

### Token Utilities

**MINE Token (Participation):**
- Cooperative membership (1,000+ MINE)
- Governance voting (stake for voting power)
- Premium feature access
- Convertible to WELL (100:1 ratio)

**WELL Token (Utility):**
- Premium health services
- Research data marketplace
- API usage fees
- Platform service payments

### Cooperative Economic Model

Revenue Distribution:
- **30%** User token buybacks
- **20%** SEAL investor repayment (3-5x cap)
- **40%** Platform operations
- **10%** Emergency reserve

### Governance Roadmap

| Phase | Timeline | Description |
|-------|----------|-------------|
| **PoA** | Months 0-18 | Validator-only governance |
| **Transition** | Months 18-24 | Gradual MINE-holder voting |
| **Cooperative** | Month 24+ | Full cooperative ownership |

See `docs/PARTICIPATION_LAYER.md` for complete documentation.

---

## Troubleshooting
- Check `.env` for correct keys and URLs
- Use `npm run dev` and monitor logs for errors
- Ensure PostgreSQL is running and accessible
- Verify contract addresses in environment variables
- Check AI Oracle service status for activity validation

---

## FAQ

**Q: How do I add a new blockchain?**
A: Update `backend/multiChainConfig.js` with the new chain's RPC and contract addresses.

**Q: How do I add a new extension?**
A: Use the extension management endpoints in the backend to enable/disable features per user.

**Q: Where do I find API docs?**
A: See `docs/UI_INTEGRATION.md`, `docs/PARTICIPATION_LAYER.md`, and `backend/README.md`.

**Q: How do I earn MINE tokens?**
A: Connect your health wearable, complete therapy sessions, contribute anonymized data, refer friends, or complete health surveys. See "Earning MINE Tokens" section above.

**Q: What is the difference between MINE and WELL?**
A: MINE is earned through participation and used for governance. WELL is a utility token (bought or converted from MINE) used for premium services.

**Q: How does the cooperative model work?**
A: Platform revenue is split 30% user buybacks, 20% SEAL investor repayment (capped at 3-5x), 40% operations, 10% reserve. After Month 24, governance transitions to MINE holders.

**Q: What is the SEAL investment model?**
A: SEAL (Sustainable Equity for Autonomous Legacies) provides investors with capped returns (3-5x) without taking equity. Once the cap is reached, investor payments stop and funds redirect to user buybacks.

**Q: How is my data protected?**
A: Only data hashes are stored on-chain. Personal health information (PHI) remains off-chain. Access is controlled through smart contracts with granular permissions.

---

For more help, open an issue on GitHub or contact the maintainers.

---

*Last Updated: 2026-02-05*
*Version: 2.0.0*
