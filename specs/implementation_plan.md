# Implementation Plan - Payment Context for GovernanceCore

This plan outlines the addition of a comprehensive Payment context to the existing `GovernanceCore` Phoenix application. The system will handle service registration, subscription management with credits, USDC transaction verification via blockchain RPC, and request logging.

## User Review Required

> [!IMPORTANT]
> - **Blockchain RPC**: The `blockchain.ex` module will require an Alchemy (or similar) RPC URL. This should ideally be configured via environment variables.
> - **Dependencies**: `httpoison` will be added to `mix.exs`.
> - **Idempotency**: `payment_transactions` will use `tx_hash` as a unique identifier to prevent double-crediting.

## Proposed Changes

### Dependencies

#### [MODIFY] [mix.exs](file:///B:/DEV/HAREZM_EKOSISTEMI/AGENTANDBOT/GOVERNANCE_CORE/mix.exs)
- Add `{:httpoison, "~> 2.0"}` to the dependencies.

### Database Migrations

#### [NEW] `priv/repo/migrations/create_payment_services.exs`
- Table: `payment_services` (id: uuid, name, slug, owner_wallet, endpoint_url, price_per_request, active).

#### [NEW] `priv/repo/migrations/create_payment_subscriptions.exs`
- Table: `payment_subscriptions` (id: uuid, service_id, buyer_wallet, api_key, credits_remaining).

#### [NEW] `priv/repo/migrations/create_payment_transactions.exs`
- Table: `payment_transactions` (id: uuid, service_id, subscription_id, buyer_wallet, amount_usdc, tx_hash, chain, status, credits_added).

#### [NEW] `priv/repo/migrations/create_payment_request_logs.exs`
- Table: `payment_request_logs` (id: uuid, subscription_id, service_id, status).

### Schemas

#### [NEW] [service.ex](file:///B:/DEV/HAREZM_EKOSISTEMI/AGENTANDBOT/GOVERNANCE_CORE/lib/governance_core/payment/schema/service.ex)
#### [NEW] [subscription.ex](file:///B:/DEV/HAREZM_EKOSISTEMI/AGENTANDBOT/GOVERNANCE_CORE/lib/governance_core/payment/schema/subscription.ex)
#### [NEW] [transaction.ex](file:///B:/DEV/HAREZM_EKOSISTEMI/AGENTANDBOT/GOVERNANCE_CORE/lib/governance_core/payment/schema/transaction.ex)
#### [NEW] [request_log.ex](file:///B:/DEV/HAREZM_EKOSISTEMI/AGENTANDBOT/GOVERNANCE_CORE/lib/governance_core/payment/schema/request_log.ex)

### Logic & Contexts

#### [NEW] [blockchain.ex](file:///B:/DEV/HAREZM_EKOSISTEMI/AGENTANDBOT/GOVERNANCE_CORE/lib/governance_core/payment/blockchain.ex)
- Logic for `eth_getTransactionReceipt` and parsing ERC-20 Transfer events for USDC on Base, Arbitrum, and Polygon.

#### [NEW] [credits.ex](file:///B:/DEV/HAREZM_EKOSISTEMI/AGENTANDBOT/GOVERNANCE_CORE/lib/governance_core/payment/credits.ex)
- Functions to `deduct_credit/1` and `add_credits/2`.

#### [NEW] [payments.ex](file:///B:/DEV/HAREZM_EKOSISTEMI/AGENTANDBOT/GOVERNANCE_CORE/lib/governance_core/payment/payments.ex)
- Main context for finding services, verifying subscriptions, and processing incoming payments.

### Web Layer

#### [NEW] [service_controller.ex](file:///B:/DEV/HAREZM_EKOSISTEMI/AGENTANDBOT/GOVERNANCE_CORE/lib/governance_core_web/controllers/api/service_controller.ex)
#### [NEW] [verify_controller.ex](file:///B:/DEV/HAREZM_EKOSISTEMI/AGENTANDBOT/GOVERNANCE_CORE/lib/governance_core_web/controllers/api/verify_controller.ex)
#### [NEW] [payment_controller.ex](file:///B:/DEV/HAREZM_EKOSISTEMI/AGENTANDBOT/GOVERNANCE_CORE/lib/governance_core_web/controllers/api/payment_controller.ex)

#### [MODIFY] [router.ex](file:///B:/DEV/HAREZM_EKOSISTEMI/AGENTANDBOT/GOVERNANCE_CORE/lib/governance_core_web/router.ex)
- Add routes for API v1 services and payments.
- Add browser scope for `/payment/dashboard`.

#### [NEW] [payment_dashboard_live.ex](file:///B:/DEV/HAREZM_EKOSISTEMI/AGENTANDBOT/GOVERNANCE_CORE/lib/governance_core_web/live/payment_dashboard_live.ex)

### Astro Integration (E-ANY-ONLINE)

#### [NEW] [payment.ts](file:///B:/DEV/HAREZM_EKOSISTEMI/E-ANY-ONLINE/src/middleware/payment.ts)
#### [NEW] [generate-icon.ts](file:///B:/DEV/HAREZM_EKOSISTEMI/E-ANY-ONLINE/src/pages/api/generate-icon.ts)

## Open Questions

- **RPC URL**: Which environment variable should I use for the Alchemy RPC URL?
- **Package Pricing**: Should I hardcode the package definitions (starter, basic, pro) in the controller or should they be in the database? (Defaulting to controller as per request description).

## Verification Plan

### Automated Tests
- Run `mix test` (existing tests).
- Mock blockchain RPC calls for verifying the `Blockchain` module.

### Manual Verification
- Test `POST /services/:slug/verify` with valid and invalid API keys.
- Test `POST /payments/submit` with a mock transaction hash (using a mock RPC responder if possible).
- Access `/payment/dashboard` to verify data aggregation.
