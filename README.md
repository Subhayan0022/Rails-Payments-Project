# Payment Gateway API

A production-grade mini payment gateway API built with Ruby on Rails. Designed with a focus on reliability, idempotency, asynchronous processing, fraud detection, and observability.

---

## Tech Stack

| Layer | Technology |
|---|---|
| API | Ruby on Rails 8.1 (API mode) |
| Database | PostgreSQL 16 |
| Background Jobs | Sidekiq 7 + Redis 7 |
| State Machine | AASM |
| Rate Limiting | Rack::Attack (Redis-backed) |
| HTTP Client | Faraday |
| Logging | Lograge (structured JSON) |
| API Docs | OpenAPI 3 + Swagger UI (rswag) |
| Testing | RSpec, FactoryBot, WebMock |
| Infrastructure | Docker + Docker Compose |

---

## Feature Status

- [x] Rails API project setup with Docker Compose
- [x] PostgreSQL + Redis + Sidekiq wired up
- [x] CORS, rate limiting, structured JSON logging
- [x] Payment model with AASM state machine (`pending → authorized → captured / failed`)
- [x] `POST /api/v1/payments` and `GET /api/v1/payments/:id`
- [x] Idempotency-Key header support (24h replay protection)
- [x] Card payments (sync) and bank transfer (async via Sidekiq)
- [x] Webhook delivery with HMAC-SHA256 signatures and exponential backoff retries
- [x] Webhook outbox sweeper — re-drives stuck deliveries, retires exhausted ones
- [x] Multi-currency allow-list (USD, JPY, INR) — no conversion yet
- [x] Fraud detection with rule-based risk scoring
- [x] Multi-tenant API key authentication (`Authorization: Bearer pk_live_…`)
- [x] `/api/v1/metrics` observability endpoint
- [x] Redis-backed rate limiting (shared across processes)
- [x] RSpec test suite (model, request, service)
- [x] OpenAPI / Swagger documentation (`/api-docs`)

---

## Quick Start

```bash
# Copy env config
cp .env.example .env

# Start all services
docker compose up --build

# In a separate terminal — create DB and run migrations
docker compose exec app bundle exec rails db:create db:migrate
```

The API will be available at `http://localhost:3000`.
Sidekiq Web UI: `http://localhost:3000/sidekiq` (HTTP Basic auth via `SIDEKIQ_USER` / `SIDEKIQ_PASSWORD`; in production the dashboard is not mounted unless both are set).

---

## Architecture Overview

```
POST /api/v1/payments
       │
       ▼
PaymentsController          (thin — validates, delegates)
       │
       ▼
Payments::CreateService     (idempotency → fraud check → persist → dispatch)
       │
       ├──► Fraud::RiskAssessor   (score 0–100; blocks at ≥ 75)
       │
       ├──► card ──► CardProcessor          (sync; immediate result)
       │
       └──► bank_transfer ──► ProcessPaymentJob   (async Sidekiq worker)
                                  │
                                  ▼
                          BankTransferProcessor

AASM state transitions on Payment fire:
       captured ──► WebhookDelivery row ──► DeliverWebhookJob ──► DeliveryService
       failed   ──► WebhookDelivery row ──► DeliverWebhookJob ──► DeliveryService
                                                         │
                                                         ▼
                                            Merchant endpoint (HMAC-signed POST)
```

---

## API

Interactive Swagger UI is available at `/api-docs` (OpenAPI 3 spec at `swagger/v1/swagger.yaml`).

### Authentication

Every `/api/v1` endpoint requires a merchant API key sent as a bearer token:

```
Authorization: Bearer pk_live_<token>
```

Keys are issued per merchant via `ApiKey.generate!(merchant:)`, stored only as a SHA-256 hash, and can be revoked. All resources are scoped to the calling merchant — one merchant cannot read or affect another's payments, metrics, or idempotency keys. Missing, malformed, revoked, or inactive-merchant keys return `401 Unauthorized`.

### Create Payment

`POST /api/v1/payments`

Headers:
```
Authorization: Bearer pk_live_<token>
Content-Type: application/json
Idempotency-Key: <unique-key>   # optional but recommended
```

Body:
```json
{
  "payment": {
    "amount": 5000,
    "currency": "USD",
    "payment_method": "card",
    "customer_email": "customer@example.com",
    "payment_details": { "card_number": "4242424242424242" }
  }
}
```

Responses:
- `201 Created` — payment processed synchronously (card) or queued (bank_transfer)
- `200 OK` — cached idempotent response (same Idempotency-Key replayed within 24h)
- `422 Unprocessable Entity` — validation error or fraud block

### Get Payment

`GET /api/v1/payments/:id`

Returns the payment with current status and timestamps. Returns `404` if the payment belongs to another merchant.

### Metrics

`GET /api/v1/metrics?window=24h`

Returns aggregate counts and captured volume for the calling merchant. `window` accepts `1h`, `24h`, `7d`, `30d`, or `all` (default).

```json
{
  "window": "24h",
  "payments": { "total": 42, "by_status": { "captured": 30, "failed": 8, "pending": 4 }, "success_rate": 0.79 },
  "volume_captured": { "USD": "125000.0", "INR": "8400.0" },
  "webhooks": { "by_status": { "delivered": 28, "failed": 2 } },
  "generated_at": "2026-05-21T12:00:00Z"
}
```

---

## Webhooks

When a payment transitions to `captured` or `failed`, a `WebhookDelivery` row is created and `DeliverWebhookJob` enqueued. The job POSTs a signed JSON payload to the configured endpoint.

Headers sent:
```
Content-Type: application/json
X-Webhook-Signature: <hex HMAC-SHA256 of body>
X-Webhook-Event: payment.succeeded | payment.failed
```

Payload:
```json
{
  "event": "payment.succeeded",
  "delivered_at": "2026-04-24T13:35:56Z",
  "data": {
    "id": "…",
    "status": "captured",
    "amount": 5000,
    "currency": "USD",
    "payment_method": "card",
    "customer_email": "…"
  }
}
```

Retry policy: `DeliverWebhookJob` retries with exponential backoff. As a safety net, `Webhooks::SweepOutboxJob` runs every 5 minutes (sidekiq-scheduler) and re-enqueues any delivery still `pending`/`failed` and past its `next_retry_at`, up to `WebhookDelivery::MAX_ATTEMPTS` (8); deliveries past the cap are marked `exhausted` and no longer retried. This makes delivery resilient to worker crashes and lost jobs.

Verify signatures using `Webhooks::SignatureService.verify(payload_string, signature_header)`.

---

## Fraud Detection

`Fraud::RiskAssessor` runs before persistence. Rules contribute points; a score ≥ 75 blocks the payment (no DB row created).

| Rule | Points |
|---|---|
| Amount > 500,000 minor units | +50 |
| Amount > 100,000 minor units | +30 |
| Disposable email domain | +40 |
| ≥ 3 payments from same email in last 10 min | +50 |
| Card number ends in `0000` | +20 |

Scores below the threshold are persisted on `payments.risk_score` for post-hoc analysis.

---

## Rate Limiting

Rack::Attack throttles:
- **100 req / 60s per IP** — global
- **20 POST /payments / 60s per IP** — tighter payment creation

Requests missing a `User-Agent` are blocked. Throttled responses return `429` with a JSON body. Counters are backed by Redis (`RedisCacheStore`, namespaced `rack_attack`) so they are shared across processes and survive restarts; the test environment uses an in-process `MemoryStore`, and the store falls back to memory if Redis is unreachable at boot.

---

## Environment Variables

| Variable | Description | Default |
|---|---|---|
| `DB_HOST` | PostgreSQL host | `postgres` |
| `DB_USERNAME` | PostgreSQL user | `postgres` |
| `DB_PASSWORD` | PostgreSQL password | `password` |
| `REDIS_URL` | Redis connection URL (Sidekiq + rate limiting) | `redis://redis:6379/0` |
| `RACK_ATTACK_REDIS_URL` | Override Redis URL for rate-limit counters | falls back to `REDIS_URL` |
| `WEBHOOK_SECRET` | HMAC signing secret for webhooks | — |
| `WEBHOOK_ENDPOINT_URL` | Destination URL for outbound webhooks | — |
| `RAILS_MASTER_KEY` | Rails credentials key | — |
| `SIDEKIQ_USER` | HTTP Basic username for the `/sidekiq` dashboard | — |
| `SIDEKIQ_PASSWORD` | HTTP Basic password for the `/sidekiq` dashboard | — |
