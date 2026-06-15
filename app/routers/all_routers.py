"""
WastePay — Remaining Routers
waste.py  · bins.py  · lga.py  · webhooks.py  · ussd.py  · users.py
"""

# ══════════════════════════════════════════════════════════════════════════════
# waste.py — Waste deposits & credit earning
# ══════════════════════════════════════════════════════════════════════════════
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
import uuid

from app.core.core import get_db, settings  # noqa
from app.routers.auth import get_current_user
from app.models.models import User, Wallet, WasteDeposit, Transaction, TransactionType, WasteType

router = APIRouter()  # Placeholder — each file would define its own router

# Credit rate map
CREDIT_RATES = {
    WasteType.PLASTIC: 400.0,
    WasteType.PAPER: 300.0,
    WasteType.GLASS: 150.0,
    WasteType.METAL: 600.0,
    WasteType.ORGANIC: 80.0,
    WasteType.ELECTRONICS: 1200.0,
    WasteType.MIXED: 100.0,
}


class DepositRequest(BaseModel):
    waste_type: WasteType
    weight_kg: float
    bin_id: Optional[str] = None
    qr_scan_data: Optional[str] = None
    notes: Optional[str] = None


class DepositResponse(BaseModel):
    deposit_id: str
    waste_type: str
    weight_kg: float
    credit_value: float
    new_balance: float
    message: str


def create_waste_deposit(data: DepositRequest, current_user: User, db: Session) -> DepositResponse:
    credit_value = round(CREDIT_RATES.get(data.waste_type, 100.0) * data.weight_kg, 2)

    deposit = WasteDeposit(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        bin_id=data.bin_id,
        waste_type=data.waste_type,
        weight_kg=data.weight_kg,
        credit_value=credit_value,
        qr_scan_data=data.qr_scan_data,
        verified=bool(data.bin_id),   # auto-verified if from IoT bin
        notes=data.notes,
    )
    db.add(deposit)

    # Update wallet
    wallet = db.query(Wallet).filter(Wallet.user_id == current_user.id).first()
    wallet.eco_credits += credit_value
    wallet.total_earned += credit_value
    wallet.kg_deposited += data.weight_kg

    # Record transaction
    txn = Transaction(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        type=TransactionType.CREDIT_EARNED,
        amount=credit_value,
        reference=f"WP-DEPOSIT-{uuid.uuid4().hex[:12].upper()}",
        description=f"{data.weight_kg}kg {data.waste_type.value} → ₦{credit_value:.2f} Eco Credits",
        status="success",
        meta={"waste_type": data.waste_type.value, "weight_kg": data.weight_kg},
    )
    db.add(txn)
    db.commit()

    return DepositResponse(
        deposit_id=deposit.id,
        waste_type=data.waste_type.value,
        weight_kg=data.weight_kg,
        credit_value=credit_value,
        new_balance=wallet.eco_credits,
        message=f"Deposit verified! ₦{credit_value:.2f} Eco Credits added to your wallet.",
    )


# ══════════════════════════════════════════════════════════════════════════════
# bins.py — Smart Bin IoT management
# ══════════════════════════════════════════════════════════════════════════════
from app.models.models import SmartBin, BinStatus


class TelemetryPayload(BaseModel):
    bin_code: str
    fill_percent: int
    weight_kg: Optional[float] = None
    battery_mv: Optional[int] = None
    temperature_c: Optional[float] = None
    last_scan_uid: Optional[str] = None


def process_telemetry(payload: TelemetryPayload, db: Session):
    """Receive IoT telemetry from smart bin (MQTT → webhook)."""
    bin_ = db.query(SmartBin).filter(SmartBin.bin_code == payload.bin_code).first()
    if not bin_:
        raise HTTPException(404, f"Bin {payload.bin_code} not registered")

    # Update bin status
    bin_.fill_percent = payload.fill_percent
    if payload.fill_percent >= 90:
        bin_.status = BinStatus.FULL
    elif bin_.status == BinStatus.FULL and payload.fill_percent < 20:
        bin_.status = BinStatus.ACTIVE

    from datetime import datetime
    bin_.last_telemetry = datetime.utcnow()

    telemetry = BinTelemetry(
        id=str(uuid.uuid4()),
        bin_id=bin_.id,
        fill_percent=payload.fill_percent,
        weight_kg=payload.weight_kg,
        battery_mv=payload.battery_mv,
        temperature_c=payload.temperature_c,
        last_scan_uid=payload.last_scan_uid,
    )
    db.add(telemetry)
    db.commit()
    return {"status": "ok", "bin_status": bin_.status.value}


# ══════════════════════════════════════════════════════════════════════════════
# ussd.py — Africa's Talking USSD *932#
# ══════════════════════════════════════════════════════════════════════════════
from app.models.models import KYCTier

# USSD session state is stateless per AT callback
# AT sends: sessionId, phoneNumber, networkCode, serviceCode, text

USSD_MENU = """CON Welcome to WastePay *932#
1. Check Eco Credit balance
2. Pay waste levy
3. Redeem credits (pay bills)
4. Request waste pickup
5. My account"""


def handle_ussd(session_id: str, phone: str, text: str, db: Session) -> str:
    """
    Handle Africa's Talking USSD callback.
    Returns 'CON ...' for menu continuation or 'END ...' to close session.
    """
    parts = text.split("*") if text else []
    level = len(parts)

    # Level 0: Main menu
    if not text:
        return USSD_MENU

    choice = parts[0]

    # 1. Balance
    if choice == "1":
        user = db.query(User).filter(User.phone == phone).first()
        if not user or not user.wallet:
            return "END You are not registered on WastePay. Download the app to register."
        bal = user.wallet.eco_credits
        kg = user.wallet.kg_deposited
        return f"END Your WastePay balance:\nEco Credits: N{bal:.2f}\nTotal waste deposited: {kg:.1f}kg\n\nDial *932# for more options."

    # 2. Pay waste levy
    elif choice == "2":
        if level == 1:
            return "CON Enter your waste levy amount (NGN):"
        elif level == 2:
            try:
                amount = float(parts[1])
                user = db.query(User).filter(User.phone == phone).first()
                if not user:
                    return "END Not registered. Download WastePay app to register."
                if not user.wallet or user.wallet.eco_credits < amount:
                    return f"END Insufficient Eco Credits. Balance: N{user.wallet.eco_credits if user.wallet else 0:.2f}"
                # In production: deduct credits and initiate Paystack charge
                return f"END Waste levy of N{amount:.2f} paid from your Eco Credits.\nRef: WP-USSD-{uuid.uuid4().hex[:8].upper()}\nThank you!"
            except ValueError:
                return "END Invalid amount. Please enter numbers only."

    # 3. Redeem credits
    elif choice == "3":
        if level == 1:
            return "CON Choose biller:\n1. PHCN Electricity\n2. Airtime (MTN)\n3. Airtime (Glo)\n4. DSTV"
        elif level >= 2:
            billers = {"1": "PHCN Electricity", "2": "MTN Airtime", "3": "Glo Airtime", "4": "DSTV"}
            biller = billers.get(parts[1], "Unknown")
            if level == 2:
                return f"CON {biller} selected.\nEnter your account/meter number:"
            elif level == 3:
                return f"CON Enter amount to pay (NGN):"
            elif level == 4:
                try:
                    amount = float(parts[3])
                    return f"END Processing {biller} payment of N{amount:.2f}.\nYou will receive SMS confirmation.\nRef: WP-USSD-{uuid.uuid4().hex[:8].upper()}"
                except (ValueError, IndexError):
                    return "END Invalid amount."

    # 4. Request pickup
    elif choice == "4":
        return "CON Request pickup:\n1. Tomorrow morning\n2. Tomorrow afternoon\n3. This week (any day)"
    elif choice == "4*1":
        return "END Pickup scheduled for tomorrow morning. A collector will contact you.\nDial *932# to check status."
    elif choice == "4*2":
        return "END Pickup scheduled for tomorrow afternoon."
    elif choice == "4*3":
        return "END Pickup request submitted. A collector will contact you within 24 hours."

    # 5. Account
    elif choice == "5":
        user = db.query(User).filter(User.phone == phone).first()
        if not user:
            return "END Not registered. Download the WastePay app to register."
        return f"END Account: {user.full_name}\nPhone: {user.phone}\nKYC Tier: {user.kyc_tier.value}\nDownload app for full features."

    return "END Invalid option. Dial *932# to try again."


# ══════════════════════════════════════════════════════════════════════════════
# webhooks.py — Paystack webhook handler
# ══════════════════════════════════════════════════════════════════════════════
import hmac, hashlib, json


def verify_paystack_signature(payload: bytes, signature: str) -> bool:
    expected = hmac.new(
        settings.PAYSTACK_SECRET_KEY.encode(),
        payload,
        hashlib.sha512
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


def handle_paystack_event(event: dict, db: Session):
    """Process Paystack webhook events."""
    event_type = event.get("event")
    data = event.get("data", {})

    if event_type == "charge.success":
        ref = data.get("reference", "")
        txn = db.query(Transaction).filter(Transaction.reference == ref).first()
        if txn:
            txn.status = "success"
            txn.paystack_ref = data.get("id")
            db.commit()

    elif event_type == "transfer.success":
        ref = data.get("reference", "")
        txn = db.query(Transaction).filter(Transaction.reference == ref).first()
        if txn:
            txn.status = "success"
            db.commit()

    elif event_type == "transfer.failed":
        ref = data.get("reference", "")
        txn = db.query(Transaction).filter(Transaction.reference == ref).first()
        if txn:
            txn.status = "failed"
            # Refund credits
            wallet = db.query(Wallet).filter(Wallet.user_id == txn.user_id).first()
            if wallet:
                wallet.eco_credits += txn.amount
                wallet.total_redeemed -= txn.amount
            db.commit()

    return {"status": "ok"}
