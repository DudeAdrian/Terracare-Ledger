## Terracare Ledger UI Integration Guide

This guide explains how to integrate the Terracare Ledger backend as a modular extension/branch in Sofie-Systems and Heartware.

### 1. Extension/Card Structure
- Add a new card/branch to the UI dashboard for "Ledger" or "Transactions".
- Use the modular, glassmorphic, card/grid layout consistent with Sofie-Systems/Heartware.
- Color-code the ledger branch for easy identification.

### 2. API Endpoints to Use
The UI should interact with the following REST endpoints:

#### Chain Management
- `GET /api/chains` — List supported blockchains.
- `GET /api/chain/:chainId/status` — Get status of a specific chain.

#### Identity Management
- `POST /api/identity/register` — Register a new identity (user, caregiver, etc.).

#### Access Control
- `POST /api/access/grant` — Grant access to a caregiver or extension.
- `POST /api/access/revoke` — Revoke access.

#### Record Management
- `POST /api/record/update` — Update a record (e.g., health data hash).
- `GET /api/record/:patient` — Fetch a patient’s record.

#### Audit Logging
- `POST /api/audit/log` — Log an audit event (for transparency and compliance).

### 3. Extension Management
- Allow users to enable/disable the Ledger extension from their profile/settings area.
- Store user preferences for which chains/extensions are visible.

### 4. Personalization & Accessibility
- Ensure all UI elements are accessible (WCAG compliant).
- Support responsive layouts for mobile and desktop.
- Allow users to personalize which ledger features/cards are shown.

### 5. Real-Time Updates (Optional)
- Use polling or WebSocket subscriptions to update the UI when new transactions or records are added.

### 6. Example Card Layout (Pseudocode)

```
<LedgerCard>
  <ChainSelector chains={chains} />
  <BalanceDisplay />
  <TransactionHistory />
  <GrantAccessForm />
  <RecordPanel />
  <AuditLogPanel />
</LedgerCard>
```

### 7. Security & Privacy
- Only show data the user is authorized to see (enforced by backend and UI logic).
- Never display private keys or sensitive on-chain data in the UI.

---
For further extension, see the backend API documentation and smart contract interfaces.