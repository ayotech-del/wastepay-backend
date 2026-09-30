"""Paystack checkout with server-owned intent and atomic settlement."""
import uuid,json,hmac,hashlib
from decimal import Decimal, ROUND_HALF_UP
import httpx
from fastapi import APIRouter,Depends,HTTPException,Request
from pydantic import BaseModel,Field,ConfigDict
from sqlalchemy import Column,String,Integer,ForeignKey,update
from sqlalchemy.orm import Session
from app.core.database import Base,get_db
from app.core.core import settings
from app.core.permissions import require_admin
from app.models.models import User,Wallet,Transaction,TransactionType
from app.routers.auth import get_current_user
router=APIRouter()
class PaymentIntent(Base):
    __tablename__='payment_intents'
    reference=Column(String,primary_key=True)
    user_id=Column(String,ForeignKey('users.id'),nullable=False)
    amount_kobo=Column(Integer,nullable=False)
    purpose=Column(String,nullable=False)
    invoice_id=Column(String,ForeignKey('invoices.id'))
    status=Column(String,nullable=False,default='pending')
class InitPayRequest(BaseModel):
    model_config=ConfigDict(allow_inf_nan=False)
    amount:float=Field(gt=0,le=100000000)
    purpose:str='wallet_topup'
    email:str|None=None
    invoice_id:str|None=None
def kobo(amount): return int((Decimal(str(amount))*100).quantize(Decimal('1'),rounding=ROUND_HALF_UP))
def provider(path,payload=None):
    if not settings.PAYSTACK_SECRET_KEY: raise HTTPException(503,'Paystack is not configured')
    try:
        r=httpx.request('POST' if payload is not None else 'GET',settings.PAYSTACK_BASE_URL+path,
            headers={'Authorization':f'Bearer {settings.PAYSTACK_SECRET_KEY}'},json=payload,timeout=20)
        result=r.json()
        if r.status_code>=400 or not result.get('status'): raise HTTPException(502,'Payment provider rejected request')
        return result['data']
    except (httpx.HTTPError,ValueError,KeyError): raise HTTPException(502,'Payment provider unavailable')
@router.post('/initialize')
def initialize(data:InitPayRequest,user=Depends(get_current_user),db:Session=Depends(get_db)):
    from app.routers.billing import Invoice,InvoiceStatus
    if data.purpose not in ('wallet_topup','levy_payment'): raise HTTPException(422,'Unsupported payment purpose')
    if data.purpose=='levy_payment':
        inv=db.get(Invoice,data.invoice_id) if data.invoice_id else None
        if not inv or inv.user_id!=user.id: raise HTTPException(403,'Invoice ownership required')
        if inv.status in (InvoiceStatus.PAID,InvoiceStatus.CANCELLED) or kobo(data.amount)>kobo(inv.amount-inv.amount_paid):
            raise HTTPException(422,'Invoice amount is invalid')
    elif data.invoice_id: raise HTTPException(422,'Invoice not allowed for wallet topup')
    email=data.email or user.email
    if not email: raise HTTPException(422,'Email is required for checkout')
    ref='WP-'+uuid.uuid4().hex.upper()
    intent=PaymentIntent(reference=ref,user_id=user.id,amount_kobo=kobo(data.amount),purpose=data.purpose,invoice_id=data.invoice_id)
    db.add(intent)
    db.add(Transaction(user_id=user.id,type=TransactionType.LEVY_PAYMENT,amount=intent.amount_kobo/100,
        reference=ref,paystack_ref=ref,status='pending',description='Paystack '+data.purpose))
    db.commit() # Persist before provider can send a callback.
    result=provider('/transaction/initialize',{'email':email,'amount':intent.amount_kobo,'reference':ref,'currency':'NGN'})
    return {'status':'initialized','reference':ref,'payment_url':result['authorization_url'],'amount_ngn':intent.amount_kobo/100}
def settle(data,db):
    from app.routers.billing import Invoice,InvoiceStatus
    intent=db.get(PaymentIntent,data.get('reference',''))
    if not intent: raise HTTPException(404,'Unknown local payment reference')
    if data.get('status')!='success': return {'status':data.get('status','pending'),'reference':intent.reference}
    if data.get('currency')!='NGN' or data.get('amount')!=intent.amount_kobo:
        raise HTTPException(409,'Payment amount or currency mismatch')
    changed=db.execute(update(PaymentIntent).where(PaymentIntent.reference==intent.reference,
        PaymentIntent.status=='pending').values(status='success'))
    if changed.rowcount==0:
        db.rollback()
        return {'status':'success','reference':intent.reference,'duplicate':True}
    amount=intent.amount_kobo/100
    if intent.purpose=='wallet_topup':
        changed=db.execute(update(Wallet).where(Wallet.user_id==intent.user_id).values(
            eco_credits=Wallet.eco_credits+amount,total_earned=Wallet.total_earned+amount))
        if changed.rowcount!=1: raise HTTPException(409,'Wallet missing')
    else:
        inv=db.query(Invoice).filter_by(id=intent.invoice_id).with_for_update().first()
        if not inv or inv.status==InvoiceStatus.CANCELLED: raise HTTPException(409,'Invoice unavailable; reconciliation required')
        # Retain full received amount, even if another checkout paid it; flag overpayments for reconciliation.
        inv.amount_paid=round(inv.amount_paid+amount,2)
        inv.status=InvoiceStatus.PAID if inv.amount_paid>=inv.amount else InvoiceStatus.PARTIAL
    db.execute(update(Transaction).where(Transaction.reference==intent.reference).values(status='success'))
    db.commit()
    return {'status':'success','reference':intent.reference,'amount_ngn':amount,'purpose':intent.purpose}
@router.get('/verify/{reference}')
def verify(reference:str,user=Depends(get_current_user),db:Session=Depends(get_db)):
    intent=db.get(PaymentIntent,reference)
    if not intent or intent.user_id!=user.id: raise HTTPException(404,'Payment not found')
    return settle(provider('/transaction/verify/'+reference),db)
@router.post('/webhook')
async def webhook(request:Request,db:Session=Depends(get_db)):
    if not settings.PAYSTACK_SECRET_KEY: raise HTTPException(503,'Paystack not configured')
    raw=await request.body()
    expected=hmac.new(settings.PAYSTACK_SECRET_KEY.encode(),raw,hashlib.sha512).hexdigest()
    if not hmac.compare_digest(expected,request.headers.get('x-paystack-signature','')):
        raise HTTPException(401,'Invalid webhook signature')
    try: event=json.loads(raw)
    except ValueError: raise HTTPException(400,'Invalid JSON')
    if not isinstance(event,dict): raise HTTPException(400,'Invalid event')
    if event.get('event')=='charge.success':
        data=event.get('data',{})
        if not isinstance(data,dict): raise HTTPException(400,'Invalid event data')
        return settle(data,db)
    return {'status':'ignored'}
@router.get('/banks')
def banks():
    data=provider('/bank?country=nigeria&perPage=100')
    return {'banks':[{'name':b['name'],'code':b['code']} for b in data]}
@router.get('/balance')
def balance(grant=Depends(require_admin)):
    return {'balances':provider('/balance')}
class AccountRequest(BaseModel):
    bank_code:str=Field(pattern=r'^\d{3,6}$')
    account_number:str=Field(pattern=r'^\d{10}$')
@router.post('/verify-account')
def account(data:AccountRequest,user=Depends(get_current_user)):
    result=provider('/bank/resolve?account_number='+data.account_number+'&bank_code='+data.bank_code)
    return {'verified':True,**result}
