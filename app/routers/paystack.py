from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
import uuid, httpx, hmac, hashlib, json
from app.core.core import get_db, settings
from app.models.models import User, Wallet, Transaction, TransactionType
from app.routers.auth import get_current_user

router = APIRouter()
HEADERS = {"Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}", "Content-Type": "application/json"}
BASE = settings.PAYSTACK_BASE_URL

class InitPayRequest(BaseModel):
    amount: float; purpose: str = "wallet_topup"
    email: Optional[str] = None; invoice_id: Optional[str] = None

class TransferRequest(BaseModel):
    amount: float; bank_code: str; account_number: str
    account_name: str; reason: str = "WastePay payment"

class VerifyAccountRequest(BaseModel):
    account_number: str; bank_code: str

@router.post("/initialize")
def initialize_payment(data: InitPayRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    ref = f"WP-{data.purpose.upper()[:6]}-{uuid.uuid4().hex[:12].upper()}"
    email = data.email or current_user.email or f"{current_user.phone.replace('+','')}@wastepay.ng"
    try:
        resp = httpx.post(f"{BASE}/transaction/initialize", headers=HEADERS, json={
            "email": email, "amount": int(data.amount * 100), "reference": ref,
            "metadata": {"user_id": current_user.id, "purpose": data.purpose, "invoice_id": data.invoice_id},
            "channels": ["card", "bank", "ussd", "bank_transfer"],
        }, timeout=30)
        result = resp.json()
        if result.get("status"):
            db.add(Transaction(id=str(uuid.uuid4()), user_id=current_user.id,
                type=TransactionType.LEVY_PAYMENT, amount=data.amount, reference=ref,
                description=f"Paystack — {data.purpose}", status="pending", paystack_ref=ref))
            db.commit()
            return {"status":"initialized","reference":ref,
                    "payment_url":result["data"]["authorization_url"],"amount_ngn":data.amount}
        raise HTTPException(400, result.get("message","Paystack failed"))
    except httpx.TimeoutException: raise HTTPException(504, "Paystack timeout")

@router.get("/verify/{reference}")
def verify_payment(reference: str, db: Session = Depends(get_db)):
    try:
        resp = httpx.get(f"{BASE}/transaction/verify/{reference}", headers=HEADERS, timeout=30)
        result = resp.json()
        if not result.get("status"): raise HTTPException(400, "Verification failed")
        data = result["data"]; amount = data.get("amount",0)/100
        status = data.get("status"); meta = data.get("metadata",{})
        user_id = meta.get("user_id"); purpose = meta.get("purpose","")
        txn = db.query(Transaction).filter(Transaction.paystack_ref==reference).first()
        if txn: txn.status = "success" if status=="success" else "failed"; db.commit()
        if status=="success" and purpose=="wallet_topup" and user_id:
            wallet = db.query(Wallet).filter(Wallet.user_id==user_id).first()
            if wallet: wallet.eco_credits+=amount; wallet.total_earned+=amount; db.commit()
        return {"status":status,"reference":reference,"amount_ngn":amount,"purpose":purpose}
    except httpx.TimeoutException: raise HTTPException(504,"Paystack timeout")

@router.get("/banks")
def list_banks():
    try:
        resp = httpx.get(f"{BASE}/bank?country=nigeria&perPage=100", headers=HEADERS, timeout=30)
        banks = resp.json().get("data",[])
        return {"count":len(banks),"banks":[{"name":b["name"],"code":b["code"]} for b in banks]}
    except Exception as e: raise HTTPException(502, str(e))

@router.post("/verify-account")
def verify_account(data: VerifyAccountRequest):
    try:
        resp = httpx.get(f"{BASE}/bank/resolve?account_number={data.account_number}&bank_code={data.bank_code}", headers=HEADERS, timeout=30)
        result = resp.json()
        if result.get("status"):
            return {"verified":True,"account_name":result["data"]["account_name"],"account_number":result["data"]["account_number"]}
        raise HTTPException(400,"Account not found")
    except httpx.TimeoutException: raise HTTPException(504,"Timeout")

@router.get("/balance")
def check_balance():
    try:
        resp = httpx.get(f"{BASE}/balance", headers=HEADERS, timeout=30)
        result = resp.json()
        if result.get("status"):
            return {"balances":[{"currency":b["currency"],"balance_ngn":b["balance"]/100} for b in result["data"]]}
        raise HTTPException(400,"Could not fetch balance")
    except Exception as e: raise HTTPException(502, str(e))

@router.post("/webhook")
async def paystack_webhook(request: Request, db: Session = Depends(get_db)):
    body = await request.body()
    event = json.loads(body); event_type = event.get("event"); data = event.get("data",{})
    ref = data.get("reference",""); meta = data.get("metadata",{})
    if event_type == "charge.success":
        amount = data.get("amount",0)/100; user_id = meta.get("user_id"); purpose = meta.get("purpose","")
        txn = db.query(Transaction).filter(Transaction.paystack_ref==ref).first()
        if txn: txn.status="success"
        if purpose=="wallet_topup" and user_id:
            wallet = db.query(Wallet).filter(Wallet.user_id==user_id).first()
            if wallet: wallet.eco_credits+=amount; wallet.total_earned+=amount
        invoice_id = meta.get("invoice_id")
        if invoice_id:
            from app.routers.billing import Invoice, InvoiceStatus
            inv = db.query(Invoice).filter(Invoice.id==invoice_id).first()
            if inv:
                inv.amount_paid+=amount
                inv.status=InvoiceStatus.PAID if inv.amount_paid>=inv.amount else InvoiceStatus.PARTIAL
        db.commit()
    elif event_type in ["transfer.success","transfer.failed"]:
        txn = db.query(Transaction).filter(Transaction.paystack_ref==ref).first()
        if txn: txn.status="success" if event_type=="transfer.success" else "failed"; db.commit()
    return {"status":"ok"}
