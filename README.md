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
| Rate Limiting | Rack::Attack |
| HTTP Client | Faraday |
| Logging | Lograge (structured JSON) |
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
- [x] Multi-currency allow-list (USD, JPY, INR) — no conversion yet
- [x] Fraud detection with rule-based risk scoring
- [ ] `/api/v1/metrics` observability endpoint
- [ ] RSpec test suite (unit, request, integration)
- [ ] OpenAPI / Swagger documentation

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
Sidekiq Web UI: `http://localhost:3000/sidekiq`

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

### Create Payment

`POST /api/v1/payments`

Headers:
```
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

Returns the payment with current status and timestamps.

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

Retry policy: exponential backoff, up to 5 attempts via ActiveJob's `polynomially_longer`.
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

Requests missing a `User-Agent` are blocked. Throttled responses return `429` with a JSON body. Backed by an in-process `MemoryStore` in dev; swap for `RedisCacheStore` in production for shared counters.

---

## Environment Variables

| Variable | Description | Default |
|---|---|---|
| `DB_HOST` | PostgreSQL host | `postgres` |
| `DB_USERNAME` | PostgreSQL user | `postgres` |
| `DB_PASSWORD` | PostgreSQL password | `password` |
| `REDIS_URL` | Redis connection URL | `redis://redis:6379/0` |
| `WEBHOOK_SECRET` | HMAC signing secret for webhooks | — |
| `WEBHOOK_ENDPOINT_URL` | Destination URL for outbound webhooks | — |
| `RAILS_MASTER_KEY` | Rails credentials key | — |
