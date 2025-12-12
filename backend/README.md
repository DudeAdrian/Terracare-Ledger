# Terracare Ledger Backend

## Overview
This backend provides a multi-chain API for the Terracare Ledger, supporting integration with Sofie-Systems and Heartware UI extensions.

## Features
- Multi-chain support (Terracare, Ethereum, Polygon, etc.)
- Core endpoints for identity, access, records, and audit logging
- Modular, extensible architecture

## Getting Started

1. Install dependencies:
   ```
   npm install
   ```
2. Copy `.env.example` to `.env` and fill in your keys:
   ```
   cp .env.example .env
   ```
3. Start the backend:
   ```
   npm run dev
   ```

## API Endpoints
See `docs/UI_INTEGRATION.md` for endpoint details and integration guidance.

## Next Steps
- Wire up endpoints to smart contracts using Ethers.js
- Add database for analytics and user settings
- Expand API for future extensions
