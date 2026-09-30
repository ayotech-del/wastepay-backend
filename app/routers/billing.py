from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from sqlalchemy import Column, String, Float, Integer, Boolean, DateTime, Enum, ForeignKey, Text
from sqlalchemy.sql import func
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List
import uuid, httpx, enum
from datetime import datetime, timedelta
from app.core.core import get_db, settings
from app.core.database import Base, engine
from app.models.models import User, Wallet, Transaction, TransactionType, LGA

from app.core.permissions import require_admin, require_finance, check_lga, allowed_lgas, audit
from app.routers.auth import get_current_user
router = APIRouter()

class InvoiceStatus(str, enum.Enum):
    DRAFT="draft"; SENT="sent"; PARTIAL="partial"; PAID="paid"; OVERDUE="overdue"; CANCELLED="cancelled"

class LevyType(str, enum.Enum):
    RESIDENTIAL="residential"; COMMERCIAL="commercial"; INDUSTRIAL="industrial"

class Invoice(Base):
    __tablename__ = "invoices"
    id             = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    invoice_number = Column(String(30), unique=True, nullable=False)
    lga_id         = Column(String, ForeignKey("lgas.id"), nullable=False)
    user_id        = Column(String, ForeignKey("users.id"), nullable=True)
    zone           = Column(String(200), nullable=True)
    levy_type      = Column(Enum(LevyType), default=LevyType.RESIDENTIAL)
    amount         = Column(Float, nullable=False)
    amount_paid    = Column(Float, default=0.0)
    status         = Column(Enum(InvoiceStatus), default=InvoiceStatus.DRAFT)
    billing_period = Column(String(20), nullable=False)
    due_date       = Column(DateTime(timezone=True), nullable=False)
    description    = Column(String(500), nullable=True)
    paystack_ref   = Column(String, nullable=True)
    reminder_sent  = Column(Boolean, default=False)
    paid_at        = Column(DateTime(timezone=True), nullable=True)
    created_at     = Column(DateTime(timezone=True), server_default=func.now())



class GenerateInvoiceRequest(BaseModel):
    lga_id: str; levy_type: LevyType = LevyType.RESIDENTIAL
    contract_id: str | None = None
    model_config = ConfigDict(allow_inf_nan=False)
    amount: float = Field(gt=0, le=100000000); billing_period: str
    zone: Optional[str] = None; user_id: Optional[str] = None
    due_days: int = Field(default=14, ge=1, le=365); description: Optional[str] = None

class BulkInvoiceRequest(BaseModel):
    lga_id: str; levy_type: LevyType = LevyType.RESIDENTIAL
    model_config = ConfigDict(allow_inf_nan=False)
    amount: float = Field(gt=0, le=100000000); billing_period: str
    zone: str; household_count: int = Field(gt=0, le=1000); due_days: int = Field(default=14, ge=1, le=365)

class PayInvoiceRequest(BaseModel):
    model_config = ConfigDict(allow_inf_nan=False)
    payment_method: str; amount: Optional[float] = Field(default=None, gt=0)

def gen_invoice_number():
    return f"WP-INV-{datetime.utcnow().strftime('%Y%m')}-{uuid.uuid4().hex[:6].upper()}"

def inv_out(inv):
    from sqlalchemy.orm import object_session
    from app.models.access import ServiceInvoice,ServiceContract,Company
    db=object_session(inv)
    link=db.get(ServiceInvoice,inv.id) if db else None
    contract=db.get(ServiceContract,link.contract_id) if link else None
    company=db.get(Company,contract.company_id) if contract else None
    return {"contractor_id":company.id if company else None,"contractor_name":company.name if company else None,"id":inv.id,"invoice_number":inv.invoice_number,"lga_id":inv.lga_id,
            "zone":inv.zone,"levy_type":inv.levy_type.value,"amount":inv.amount,
            "amount_paid":inv.amount_paid,"balance":round(inv.amount-inv.amount_paid,2),
            "status":inv.status.value,"billing_period":inv.billing_period,
            "due_date":str(inv.due_date),"description":inv.description,"created_at":str(inv.created_at)}

@router.post("/invoice/generate", status_code=201)
def generate_invoice(data: GenerateInvoiceRequest, grant=Depends(require_finance), db: Session = Depends(get_db)):
    check_lga(grant, data.lga_id)
    lga = db.query(LGA).filter(LGA.id == data.lga_id).first()
    if not lga: raise HTTPException(404, f"LGA not found")
    from app.models.access import ServiceContract,ServiceInvoice
    contract=db.get(ServiceContract,data.contract_id) if data.contract_id else None
    if data.contract_id:
        if not contract or not contract.active or contract.lga_id!=data.lga_id:raise HTTPException(422,'Service contract must be active in this LGA')
        if data.user_id and data.user_id!=contract.user_id:raise HTTPException(422,'Invoice consumer must match the service contract')
    if data.user_id and not db.get(User,data.user_id):raise HTTPException(404,'Consumer not found')
    inv = Invoice(invoice_number=gen_invoice_number(), lga_id=data.lga_id,
        user_id=contract.user_id if contract else data.user_id, zone=data.zone, levy_type=data.levy_type,
        amount=data.amount, billing_period=data.billing_period,
        due_date=datetime.utcnow()+timedelta(days=data.due_days),
        description=data.description or f"{data.levy_type.value.title()} waste levy — {lga.name} — {data.billing_period}",
        status=InvoiceStatus.SENT)
    db.add(inv);db.flush()
    if contract:db.add(ServiceInvoice(invoice_id=inv.id,contract_id=contract.id))
    audit(db,grant.user_id,'invoice.created',inv.id,lga_id=inv.lga_id,company_id=contract.company_id if contract else None)
    db.commit();db.refresh(inv)
    return {"status":"created","invoice":inv_out(inv)}

@router.post("/invoice/bulk", status_code=201)
def generate_bulk(data: BulkInvoiceRequest, grant=Depends(require_finance), db: Session = Depends(get_db)):
    check_lga(grant, data.lga_id)
    lga = db.query(LGA).filter(LGA.id == data.lga_id).first()
    if not lga: raise HTTPException(404, "LGA not found")
    due = datetime.utcnow()+timedelta(days=data.due_days)
    created=[]
    for i in range(data.household_count):
        inv = Invoice(invoice_number=gen_invoice_number(), lga_id=data.lga_id,
            zone=data.zone, levy_type=data.levy_type, amount=data.amount,
            billing_period=data.billing_period, due_date=due,
            description=f"{data.levy_type.value.title()} levy — {data.zone} — Unit {i+1}",
            status=InvoiceStatus.SENT)
        db.add(inv); created.append(inv)
    db.commit()
    return {"status":"bulk_created","invoices_generated":data.household_count,
            "total_billed":data.amount*data.household_count,"zone":data.zone}

@router.get("/invoices/{lga_id}")
def list_invoices(lga_id: str, status: Optional[str]=None, skip: int=0, limit: int=50, grant=Depends(require_admin), db: Session=Depends(get_db)):
    check_lga(grant, lga_id)
    if skip < 0 or not 1 <= limit <= 200: raise HTTPException(422,"Invalid pagination")
    q = db.query(Invoice).filter(Invoice.lga_id==lga_id)
    if status: q=q.filter(Invoice.status==status)
    return [inv_out(i) for i in q.order_by(Invoice.created_at.desc()).offset(skip).limit(limit).all()]

@router.get("/invoice/{invoice_id}")
def get_invoice(invoice_id: str, user=Depends(get_current_user), db: Session=Depends(get_db)):
    inv=db.query(Invoice).filter(Invoice.id==invoice_id).with_for_update().first()
    if not inv: raise HTTPException(404,"Invoice not found")
    if inv.user_id != user.id: raise HTTPException(403,"Not your invoice")
    return inv_out(inv)

@router.post("/invoice/{invoice_id}/pay")
def pay_invoice(invoice_id: str, data: PayInvoiceRequest, user=Depends(get_current_user), db: Session=Depends(get_db)):
    from app.routers.auth import get_current_user
    inv=db.query(Invoice).filter(Invoice.id==invoice_id).with_for_update().first()
    if not inv: raise HTTPException(404,"Invoice not found")
    if inv.status in [InvoiceStatus.PAID,InvoiceStatus.CANCELLED]:
        raise HTTPException(400,f"Invoice already {inv.status.value}")
    if inv.user_id != user.id: raise HTTPException(403,"Not your invoice")
    amount=data.amount if data.amount is not None else (inv.amount-inv.amount_paid)
    if amount <= 0 or amount > round(inv.amount-inv.amount_paid,2): raise HTTPException(422,"Invalid payment amount")
    ref=f"WP-BILL-{uuid.uuid4().hex[:12].upper()}"
    if data.payment_method=="eco_credits":
        from sqlalchemy import update
        result=db.execute(update(Wallet).where(Wallet.user_id==user.id, Wallet.eco_credits>=amount).values(
            eco_credits=Wallet.eco_credits-amount,total_redeemed=Wallet.total_redeemed+amount))
        if result.rowcount != 1: raise HTTPException(400,"Insufficient Eco Credits")
        db.add(Transaction(user_id=user.id,type=TransactionType.LEVY_PAYMENT,amount=amount,reference=ref,status="success",description=inv.invoice_number))
        inv.amount_paid+=amount
        inv.status=InvoiceStatus.PAID if inv.amount_paid>=inv.amount else InvoiceStatus.PARTIAL
        db.commit()
        return {"status":"success","method":"eco_credits","amount_paid":amount,"reference":ref,"invoice_status":inv.status.value}
    raise HTTPException(400,"Use: eco_credits | card")

@router.get("/stats/{lga_id}")
def billing_stats(lga_id: str, grant=Depends(require_admin), db: Session=Depends(get_db)):
    check_lga(grant, lga_id)
    invs=db.query(Invoice).filter(Invoice.lga_id==lga_id).all()
    billed=sum(i.amount for i in invs); collected=sum(i.amount_paid for i in invs)
    return {"lga_id":lga_id,"total_invoices":len(invs),"total_billed":round(billed,2),
            "total_collected":round(collected,2),"outstanding":round(billed-collected,2),
            "collection_rate":round(collected/billed*100 if billed>0 else 0,1),
            "paid_count":sum(1 for i in invs if i.status==InvoiceStatus.PAID),
            "overdue_count":sum(1 for i in invs if i.status==InvoiceStatus.OVERDUE)}

@router.post("/overdue/mark")
def mark_overdue(grant=Depends(require_finance), db: Session=Depends(get_db)):
    now=datetime.utcnow()
    invs=db.query(Invoice).filter(Invoice.lga_id.in_(allowed_lgas(grant,db)),Invoice.status.in_([InvoiceStatus.SENT,InvoiceStatus.PARTIAL]),Invoice.due_date<now).all()
    for i in invs: i.status=InvoiceStatus.OVERDUE
    db.commit()
    return {"marked_overdue":len(invs)}

@router.get("/my-invoices")
def my_invoices(user=Depends(get_current_user),db:Session=Depends(get_db)):
    return [inv_out(i) for i in db.query(Invoice).filter_by(user_id=user.id).order_by(Invoice.created_at.desc()).limit(100)]
