"""
WastePay — Wallet / Eco Credits Router
GET  /wallet/balance
POST /wallet/redeem         → pay utility bill with credits
POST /wallet/withdraw       → send credits to bank account
GET  /wallet/transactions   → transaction history
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List
import uuid, httpx

from app.core.core import get_db, settings
from app.routers.auth import get_current_user  # noqa
from app.models.models import User, Wallet, Transaction, TransactionType, KYCTier

router = APIRouter()

PAYSTACK_HEADERS = {
    "Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}",
    "Content-Type": "application/json",
}


# ── Schemas ──────────────────────────────────────────────────────────────────

class WalletResponse(BaseModel):
    eco_credits: float
    total_earned: float
    total_redeemed: float
    kg_deposited: float


class RedeemRequest(BaseModel):
    amount: float           # NGN amount to redeem
    biller_code: str        # Paystack biller code (e.g. "DSTV", "IKEJA-ELECTRIC")
    customer_ref: str       # Customer/account number with the biller
    description: Optional[str] = None


class WithdrawRequest(BaseModel):
    amount: float
    bank_code: str          # e.g. "058" for GTBank
    account_number: str


class TransactionOut(BaseModel):
    id: str
    type: str
    amount: float
    description: Optional[str]
    status: str
    created_at: str

    class Config:
        from_attributes = True


# ── Helpers ──────────────────────────────────────────────────────────────────

def get_daily_limit(user: User) -> float:
    limits = {
        KYCTier.TIER_1: settings.LIMIT_TIER_1,
        KYCTier.TIER_2: settings.LIMIT_TIER_2,
        KYCTier.TIER_3: settings.LIMIT_TIER_3,
    }
    return limits.get(user.kyc_tier, settings.LIMIT_TIER_1)


def check_credits(wallet: Wallet, amount: float):
    if wallet.eco_credits < amount:
        raise HTTPException(400, f"Insufficient Eco Credits. Balance: ₦{wallet.eco_credits:.2f}")


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/balance", response_model=WalletResponse)
def get_balance(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    wallet = db.query(Wallet).filter(Wallet.user_id == current_user.id).first()
    if not wallet:
        raise HTTPException(404, "Wallet not found")
    return WalletResponse(
        eco_credits=wallet.eco_credits,
        total_earned=wallet.total_earned,
        total_redeemed=wallet.total_redeemed,
        kg_deposited=wallet.kg_deposited,
    )


@router.post("/redeem")
def redeem_credits(
    data: RedeemRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Redeem Eco Credits to pay a utility bill via Paystack."""
    wallet = db.query(Wallet).filter(Wallet.user_id == current_user.id).first()
    check_credits(wallet, data.amount)

    ref = f"WP-REDEEM-{uuid.uuid4().hex[:12].upper()}"

    # Deduct credits optimistically
    wallet.eco_credits -= data.amount
    wallet.total_redeemed += data.amount

    txn = Transaction(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        type=TransactionType.CREDIT_REDEEMED,
        amount=data.amount,
        reference=ref,
        description=data.description or f"Bill payment — {data.biller_code} ({data.customer_ref})",
        status="pending",
        meta={"biller_code": data.biller_code, "customer_ref": data.customer_ref},
    )
    db.add(txn)
    db.commit()

    # Fire Paystack charge to pay biller
    try:
        resp = httpx.post(
            f"{settings.PAYSTACK_BASE_URL}/charge",
            headers=PAYSTACK_HEADERS,
            json={
                "email": current_user.email or f"{current_user.phone}@wastepay.ng",
                "amount": int(data.amount * 100),  # kobo
                "reference": ref,
                "metadata": {
                    "biller_code": data.biller_code,
                    "customer_ref": data.customer_ref,
                    "user_id": current_user.id,
                    "wastepay_type": "eco_credit_redemption",
                }
            },
            timeout=30
        )
        if resp.status_code == 200:
            txn.status = "processing"
            txn.paystack_ref = ref
            db.commit()
    except Exception:
        # Paystack call failed — refund credits
        wallet.eco_credits += data.amount
        wallet.total_redeemed -= data.amount
        txn.status = "failed"
        db.commit()
        raise HTTPException(502, "Payment gateway error. Credits have been refunded.")

    return {"status": "processing", "reference": ref, "amount": data.amount, "message": "Bill payment initiated. Credits deducted pending confirmation."}


@router.post("/withdraw")
def withdraw_to_bank(
    data: WithdrawRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Withdraw Eco Credits to bank account. Requires Tier 3 KYC."""
    if current_user.kyc_tier != KYCTier.TIER_3:
        raise HTTPException(403, "Bank withdrawals require Tier 3 KYC. Please complete BVN + selfie verification.")

    wallet = db.query(Wallet).filter(Wallet.user_id == current_user.id).first()
    check_credits(wallet, data.amount)

    ref = f"WP-WITHDRAW-{uuid.uuid4().hex[:12].upper()}"
    wallet.eco_credits -= data.amount
    wallet.total_redeemed += data.amount

    txn = Transaction(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        type=TransactionType.BANK_WITHDRAWAL,
        amount=data.amount,
        reference=ref,
        description=f"Bank withdrawal to account ending {data.account_number[-4:]}",
        status="pending",
        meta={"bank_code": data.bank_code, "account_number": data.account_number[-4:]},
    )
    db.add(txn)
    db.commit()

    # Paystack transfer
    try:
        # First create transfer recipient
        recipient_resp = httpx.post(
            f"{settings.PAYSTACK_BASE_URL}/transferrecipient",
            headers=PAYSTACK_HEADERS,
            json={
                "type": "nuban",
                "name": current_user.full_name,
                "account_number": data.account_number,
                "bank_code": data.bank_code,
                "currency": "NGN",
            },
            timeout=30
        )
        recipient_code = recipient_resp.json().get("data", {}).get("recipient_code")

        if recipient_code:
            httpx.post(
                f"{settings.PAYSTACK_BASE_URL}/transfer",
                headers=PAYSTACK_HEADERS,
                json={
                    "source": "balance",
                    "amount": int(data.amount * 100),
                    "recipient": recipient_code,
                    "reference": ref,
                    "reason": f"WastePay Eco Credit withdrawal — {current_user.full_name}",
                },
                timeout=30
            )
            txn.status = "processing"
            db.commit()

    except Exception:
        wallet.eco_credits += data.amount
        wallet.total_redeemed -= data.amount
        txn.status = "failed"
        db.commit()
        raise HTTPException(502, "Transfer failed. Credits refunded.")

    return {"status": "processing", "reference": ref, "amount": data.amount}


@router.get("/transactions", response_model=List[TransactionOut])
def get_transactions(
    skip: int = 0,
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    txns = (
        db.query(Transaction)
        .filter(Transaction.user_id == current_user.id)
        .order_by(Transaction.created_at.desc())
        .offset(skip).limit(limit)
        .all()
    )
    return [
        TransactionOut(
            id=t.id, type=t.type.value, amount=t.amount,
            description=t.description, status=t.status,
            created_at=str(t.created_at)
        ) for t in txns
    ]
