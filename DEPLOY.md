# WastePay Nigeria — Railway Deployment Guide

## Prerequisites
- Railway account at railway.app
- Railway CLI: `npm install -g @railway/cli`
- GitHub repo for wastepay-backend

---

## Step 1 — Push to GitHub

```bash
cd wastepay_backend
git init
git add .
git commit -m "feat: WastePay Nigeria API v1.0.0"
git remote add origin https://github.com/YOUR_USERNAME/wastepay-backend.git
git push -u origin main
```

---

## Step 2 — Create Railway Project

```bash
railway login
railway init          # → Create new project → "wastepay-backend"
railway link          # → Link to your project
```

Or via dashboard: railway.app → New Project → Deploy from GitHub repo

---

## Step 3 — Add PostgreSQL Plugin

In Railway dashboard:
1. Click your project
2. **+ New** → **Database** → **PostgreSQL**
3. Railway auto-sets `DATABASE_URL` in your service's env

---

## Step 4 — Set Environment Variables

In Railway dashboard → your service → Variables:

```env
# Required
SECRET_KEY=your-super-secure-random-256-bit-key
PAYSTACK_SECRET_KEY=sk_live_YOUR_PAYSTACK_KEY
PREMBLY_API_KEY=your_prembly_key
AT_USERNAME=wastepay
AT_API_KEY=your_africas_talking_key
ADMIN_PASSWORD=YourSecureAdminPassword2026!

# Optional overrides
RATE_ELECTRONICS=1200
RATE_METAL=600
RATE_PLASTIC=400
```

Generate SECRET_KEY:
```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

---

## Step 5 — Deploy

```bash
railway up
```

Railway auto-detects `railway.toml` and runs:
- Build: `pip install -r requirements.txt`
- Start: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

---

## Step 6 — Initialize Production Database

After first deploy, run the setup script:

```bash
railway run python scripts/railway_setup.py
```

This seeds:
- ✅ All 7 credit rates (₦80–₦1,200/kg)
- ✅ 10 LGAs (Lagos x5, Abuja x2, PH x2, Kano x1)
- ✅ 9 smart bins (Lagos + Abuja with GPS coordinates)
- ✅ Admin user (phone: +2349000000001)

---

## Step 7 — Verify Live API

```bash
# Get your Railway URL from dashboard (e.g. wastepay-backend.up.railway.app)
DOMAIN="https://wastepay-backend.up.railway.app"

curl $DOMAIN/health
# → {"status":"healthy"}

curl $DOMAIN/docs
# → Swagger UI
```

---

## Step 8 — Custom Domain (Optional)

In Railway dashboard → Settings → Domains → Add custom domain:
```
api.wastepay.ng → CNAME → wastepay-backend.up.railway.app
```

---

## Environment-Specific Config

| Variable | Development | Production |
|----------|-------------|------------|
| DATABASE_URL | sqlite:///./wastepay_dev.db | postgresql://... (Railway auto-set) |
| SECRET_KEY | dev-secret-key | 256-bit random hex |
| PAYSTACK_SECRET_KEY | sk_test_... | sk_live_... |
| AT_USERNAME | sandbox | wastepay |

---

## Useful Railway Commands

```bash
railway logs          # Stream live logs
railway run bash      # SSH into container
railway variables     # List env vars
railway status        # Deployment status
railway domain        # Get your URL
```

---

## Updating the App

```bash
git add .
git commit -m "feat: your change"
git push origin main
# Railway auto-deploys on push
```

---

## Monitoring

Railway dashboard shows:
- CPU / Memory usage
- Request logs
- Deploy history
- Database metrics (PostgreSQL plugin)

For production alerts, add:
- Uptime Robot (free): monitors /health endpoint
- Railway alerts: set CPU/memory thresholds in dashboard
