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
def redeem_credits(data: RedeemRequest, current_user=Depends(get_current_user)):
    raise HTTPException(503,"Utility redemption provider is not configured. No credits deducted.")

@router.post("/withdraw")
def withdraw_to_bank(data: WithdrawRequest, current_user=Depends(get_current_user)):
    raise HTTPException(503,"Bank disbursement is not configured. No credits deducted.")

@router.get("/transactions", response_model=List[TransactionOut])
def get_transactions(
    skip: int = 0,
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if skip < 0 or not 1 <= limit <= 200: raise HTTPException(422,"Invalid pagination")
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
