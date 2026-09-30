"""WastePay — Stub routers (fully expandable)"""
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from app.core.core import get_db

# ── users.py ─────────────────────────────────────────────────────────────────
router = APIRouter()  # Temporarily shared namespace for stubs

users_router = APIRouter()

@users_router.get("/me")
def get_me():
    return {"detail": "User profile endpoint — see auth router for full implementation"}

@users_router.post("/kyc/nin")
def verify_nin(nin: str, db: Session = Depends(get_db)):
    """Upgrade to Tier 2 KYC via Prembly NIN verification."""
    return {"detail": "NIN verification — integrate Prembly API with settings.PREMBLY_API_KEY"}

@users_router.post("/kyc/bvn")
def verify_bvn(bvn: str, db: Session = Depends(get_db)):
    """Upgrade to Tier 3 KYC via BVN + selfie liveness."""
    return {"detail": "BVN verification — integrate Prembly BVN lookup + liveness check"}


# ── waste.py ─────────────────────────────────────────────────────────────────
waste_router = APIRouter()

@waste_router.post("/deposit")
async def submit_deposit(request: Request, db: Session = Depends(get_db)):
    auth = request.headers.get("Authorization","")
    if not auth.startswith("Bearer "):
        from fastapi import HTTPException; raise HTTPException(401, "Not authenticated")
    from app.core.core import decode_token
    from app.models.models import User, Wallet, Transaction, TransactionType, WasteDeposit, WasteType
    import uuid
    payload = decode_token(auth.split(" ")[1])
    user = db.query(User).filter(User.id == payload["sub"]).first()
    body = await request.json()
    RATES = {"plastic":400,"paper":300,"glass":150,"metal":600,"organic":80,"electronics":1200,"mixed":100}
    wtype = body.get("waste_type","mixed")
    kg = float(body.get("weight_kg", 0))
    credit_value = round(RATES.get(wtype, 100) * kg, 2)
    wallet = db.query(Wallet).filter(Wallet.user_id == user.id).first()
    wallet.eco_credits += credit_value; wallet.total_earned += credit_value; wallet.kg_deposited += kg
    ref = f"WP-{uuid.uuid4().hex[:10].upper()}"
    db.add(WasteDeposit(id=str(uuid.uuid4()), user_id=user.id, waste_type=WasteType(wtype),
        weight_kg=kg, credit_value=credit_value, verified=True))
    db.add(Transaction(id=str(uuid.uuid4()), user_id=user.id, type=TransactionType.CREDIT_EARNED,
        amount=credit_value, reference=ref, description=f"{kg}kg {wtype} deposited", status="success"))
    db.commit()
    return {"deposit_id": ref, "waste_type": wtype, "weight_kg": kg,
            "credit_value": credit_value, "new_balance": wallet.eco_credits,
            "message": f"✅ ₦{credit_value:,.2f} Eco Credits added!"}

@waste_router.get("/rates")
def get_credit_rates():
    return {
        "rates_ngn_per_kg": {
            "plastic": 400, "paper": 300, "glass": 150,
            "metal": 600, "organic": 80, "electronics": 1200, "mixed": 100
        },
        "note": "Rates set by LGA and updateable via admin"
    }

@waste_router.get("/history")
def deposit_history():
    return {"detail": "Returns paginated deposit history for current user"}


# ── bins.py ──────────────────────────────────────────────────────────────────
bins_router = APIRouter()

@bins_router.get("/nearby")
def get_nearby_bins(lat: float, lng: float, radius_km: float = 2.0):
    """Return smart bins within radius_km of given coordinates."""
    return {"detail": f"Returns bins within {radius_km}km of ({lat}, {lng}) — PostGIS query"}

@bins_router.get("/{bin_code}/status")
def bin_status(bin_code: str, db: Session = Depends(get_db)):
    return {"bin_code": bin_code, "detail": "Real-time fill level and status from last telemetry"}

@bins_router.post("/telemetry")
def receive_telemetry(db: Session = Depends(get_db)):
    """MQTT → FastAPI webhook for IoT bin telemetry. See process_telemetry() in all_routers.py."""
    return {"detail": "Telemetry received — see process_telemetry() in all_routers.py"}


# ── lga.py ───────────────────────────────────────────────────────────────────
lga_router = APIRouter()

@lga_router.get("/dashboard")
def lga_dashboard(lga_id: str, db: Session = Depends(get_db)):
    return {"detail": "LGA waste analytics: total kg collected, credits issued, bin fill levels, collector activity"}

@lga_router.post("/contractors/pay")
def pay_contractor(contractor_id: str, amount: float, db: Session = Depends(get_db)):
    return {"detail": "Initiate Paystack transfer to collector bank account"}

@lga_router.get("/report/cbnaudio")
def cbn_audit_report(month: str, year: int):
    return {"detail": f"Generate CBN-audit-ready JSON transaction export for {month}/{year}"}


# ── webhooks.py ───────────────────────────────────────────────────────────────
webhooks_router = APIRouter()

@webhooks_router.post("/paystack")
async def paystack_webhook(request: Request, db: Session = Depends(get_db)):
    """Paystack webhook — verifies HMAC signature before processing."""
    import hashlib, hmac
    from app.core.core import settings
    body = await request.body()
    sig = request.headers.get("x-paystack-signature", "")
    # Verify signature
    expected = hmac.new(settings.PAYSTACK_SECRET_KEY.encode(), body, hashlib.sha512).hexdigest()
    if not hmac.compare_digest(expected, sig):
        raise HTTPException(400, "Invalid signature")
    import json
    event = json.loads(body)
    return {"status": "received", "event": event.get("event")}


# ── ussd.py ──────────────────────────────────────────────────────────────────
ussd_router = APIRouter()

@ussd_router.post("/callback")
async def ussd_callback(request: Request, db: Session = Depends(get_db)):
    """Africa's Talking USSD callback — form-encoded POST."""
    form = await request.form()
    session_id = form.get("sessionId", "")
    phone = form.get("phoneNumber", "")
    text = form.get("text", "")

    from app.routers.all_routers import handle_ussd
    response = handle_ussd(session_id, phone, text, db)
    from fastapi.responses import PlainTextResponse
    return PlainTextResponse(content=response)
