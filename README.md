# Payment Gateway API

> **Status: Work In Progress** — core infrastructure is set up; features are actively being built.

A production-grade mini payment gateway API built with Ruby on Rails. Designed with a focus on reliability, idempotency, asynchronous processing, and observability.

---

## Tech Stack

| Layer | Technology |
|---|---|
| API | Ruby on Rails 8.1 (API mode) |
| Database | PostgreSQL 16 |
| Background Jobs | Sidekiq 7 + Redis 7 |
| State Machine | AASM |
| Rate Limiting | Rack::Attack |
| Testing | RSpec, FactoryBot, WebMock |
| Infrastructure | Docker + Docker Compose |

---

## Planned Features

- [x] Rails API project setup with Docker Compose
- [x] PostgreSQL + Redis + Sidekiq wired up
- [x] CORS, rate limiting, structured JSON logging
- [ ] Payment model with AASM state machine (`pending → authorized → captured / failed`)
- [ ] `POST /api/v1/payments` and `GET /api/v1/payments/:id`
- [ ] Idempotency-Key header support (duplicate request protection)
- [ ] Card payments (sync) and bank transfer (async via Sidekiq)
- [ ] Webhook delivery with HMAC signatures and exponential backoff retries
- [ ] Multi-currency support (USD, JPY, INR) with mock conversion
- [ ] Basic fraud detection rules
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
PaymentsController        (thin — validates, delegates)
       │
       ▼
Payments::CreateService   (idempotency check, fraud check, persists)
       │
       ├─── card ──────► CardProcessor        (sync, immediate result)
       │
       └─── bank_transfer ► ProcessPaymentJob  (async Sidekiq worker)
                                  │
                                  ▼
                          WebhookDeliveryJob   (payment.succeeded / payment.failed)
```

More detailed architecture notes will be added as features are completed.

---

## Environment Variables

| Variable | Description | Default |
|---|---|---|
| `DB_HOST` | PostgreSQL host | `postgres` |
| `DB_USERNAME` | PostgreSQL user | `postgres` |
| `DB_PASSWORD` | PostgreSQL password | `password` |
| `REDIS_URL` | Redis connection URL | `redis://redis:6379/0` |
| `WEBHOOK_SECRET` | HMAC signing secret for webhooks | — |
| `RAILS_MASTER_KEY` | Rails credentials key | — |
