# WastePay Nigeria — FastAPI Backend

Waste Management Payment System API  
Stack: FastAPI · PostgreSQL · Paystack · Africa's Talking USSD · Firebase FCM

---

## Project Structure

```
wastepay_backend/
├── app/
│   ├── main.py                  # FastAPI app entry point
│   ├── core/
│   │   └── core.py              # Config, DB, security (JWT, bcrypt)
│   ├── models/
│   │   └── models.py            # SQLAlchemy ORM models
│   └── routers/
│       ├── auth.py              # POST /auth/register, /login, /refresh
│       ├── wallet.py            # GET /wallet/balance, POST /redeem, /withdraw
│       ├── all_routers.py       # Waste deposit logic, IoT telemetry, USSD handler
│       └── stubs.py             # Stub routers: users, waste, bins, lga, webhooks, ussd
├── requirements.txt
└── .env.example
```

---

## Setup

```bash
# 1. Clone & install
pip install -r requirements.txt

# 2. Configure environment
cp .env.example .env
# Edit .env with your Paystack, Prembly, Africa's Talking keys

# 3. Run database migrations (Alembic)
alembic upgrade head

# 4. Start server
uvicorn app.main:app --reload --port 8000
```

## Docs: http://localhost:8000/docs

---

## Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /auth/register | Register citizen (Tier 1 KYC) |
| POST | /auth/login | Login → JWT tokens |
| GET | /wallet/balance | Eco Credit balance |
| POST | /wallet/redeem | Pay utility bill with credits |
| POST | /wallet/withdraw | Withdraw credits to bank (Tier 3) |
| GET | /wallet/transactions | Transaction history |
| POST | /waste/deposit | Submit recyclable deposit → earn credits |
| GET | /waste/rates | Current NGN/kg credit rates |
| GET | /bins/nearby?lat=&lng= | Smart bins near location |
| POST | /bins/telemetry | IoT bin telemetry (MQTT → API) |
| GET | /lga/dashboard | LGA waste analytics portal |
| POST | /webhooks/paystack | Paystack event webhook |
| POST | /ussd/callback | Africa's Talking *932# USSD callback |

---

## Credit Rates (NGN per kg)

| Waste Type | Rate |
|------------|------|
| Electronics | ₦1,200/kg |
| Metal | ₦600/kg |
| Plastic | ₦400/kg |
| Paper | ₦300/kg |
| Glass | ₦150/kg |
| Organic | ₦80/kg |
| Mixed | ₦100/kg |

---

## KYC Tiers

| Tier | Requirement | Daily Limit |
|------|------------|-------------|
| Tier 1 | Phone + name | ₦20,000 |
| Tier 2 | NIN (Prembly) | ₦200,000 |
| Tier 3 | BVN + selfie | ₦5,000,000 |

---

## Deployment (Railway)

```bash
# Same Railway setup as CredionPay
railway login
railway link
railway up
```

Set all env vars in Railway dashboard. PostgreSQL via Railway plugin.

---

Built on the same FastAPI stack as CredionPay (AyoTech Ltd).
