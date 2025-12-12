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
8. [Troubleshooting](#troubleshooting)
9. [FAQ](#faq)

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
- **contracts/**: Solidity smart contracts (Identity, Access, Records, Audit)
- **backend/**: Node.js/Express API, multi-chain, modular
- **frontend/**: (planned) UI extension for Sofie-Systems/Heartware
- **docs/**: Integration and API documentation

---

## Smart Contracts
- **IdentityRegistry**: Register and manage user roles
- **AccessControl**: Grant/revoke access to records
- **RecordRegistry**: Store data hashes/pointers (no PHI)
- **AuditLog**: Transparent, append-only event log

Deploy contracts using Hardhat scripts in the root directory.

---

## Backend API
- See `backend/README.md` and `docs/UI_INTEGRATION.md` for endpoint details
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

---

## Troubleshooting
- Check `.env` for correct keys and URLs
- Use `npm run dev` and monitor logs for errors
- Ensure PostgreSQL is running and accessible

---

## FAQ
**Q: How do I add a new blockchain?**
A: Update `backend/multiChainConfig.js` with the new chain’s RPC and contract addresses.

**Q: How do I add a new extension?**
A: Use the extension management endpoints in the backend to enable/disable features per user.

**Q: Where do I find API docs?**
A: See `docs/UI_INTEGRATION.md` and `backend/README.md`.

---

For more help, open an issue on GitHub or contact the maintainers.
