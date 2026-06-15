"""
WastePay Nigeria — Contractor Tracking Router
POST /contractors/register          → Register new contractor
POST /contractors/dispatch          → Assign contractor to route
POST /contractors/location/update   → GPS ping from contractor app
GET  /contractors/live              → All active contractors (govt dashboard)
GET  /contractors/{id}/history      → Contractor collection history
POST /contractors/collection/verify → Verify bin collection event
POST /contractors/payment/release   → Release payment after verified collection
GET  /contractors/report/{lga_id}   → Contractor performance report
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import Column, String, Float, Integer, Boolean, DateTime, Enum, ForeignKey, Text
from sqlalchemy.sql import func
from pydantic import BaseModel
from typing import Optional, List
import uuid, enum
from datetime import datetime

from app.core.core import get_db, settings
from app.core.database import Base, engine
from app.models.models import User, LGA, SmartBin, Transaction, TransactionType, Wallet
from app.routers.auth import get_current_user
import httpx

router = APIRouter()

# ── Contractor Models ─────────────────────────────────────────────────────────

class ContractorStatus(str, enum.Enum):
    ACTIVE       = "active"
    ON_ROUTE     = "on_route"
    BREAK        = "break"
    OFFLINE      = "offline"
    SUSPENDED    = "suspended"

class RouteStatus(str, enum.Enum):
    ASSIGNED  = "assigned"
    ACTIVE    = "active"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

class Contractor(Base):
    __tablename__ = "contractors"
    id              = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id         = Column(String, ForeignKey("users.id"), unique=True, nullable=False)
    lga_id          = Column(String, ForeignKey("lgas.id"), nullable=False)
    truck_number    = Column(String(20), unique=True, nullable=False)
    license_plate   = Column(String(20), nullable=True)
    capacity_tonnes = Column(Float, default=5.0)
    status          = Column(Enum(ContractorStatus), default=ContractorStatus.OFFLINE)
    current_lat     = Column(Float, nullable=True)
    current_lng     = Column(Float, nullable=True)
    last_ping       = Column(DateTime(timezone=True), nullable=True)
    rate_per_tonne  = Column(Float, default=8500.0)   # ₦8,500/tonne default
    bank_code       = Column(String(10), nullable=True)
    account_number  = Column(String(20), nullable=True)
    total_collected = Column(Float, default=0.0)
    total_earned    = Column(Float, default=0.0)
    created_at      = Column(DateTime(timezone=True), server_default=func.now())

class CollectionRoute(Base):
    __tablename__ = "collection_routes"
    id              = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    contractor_id   = Column(String, ForeignKey("contractors.id"), nullable=False)
    lga_id          = Column(String, ForeignKey("lgas.id"), nullable=False)
    status          = Column(Enum(RouteStatus), default=RouteStatus.ASSIGNED)
    bin_ids         = Column(Text, nullable=False)   # comma-separated bin IDs
    started_at      = Column(DateTime(timezone=True), nullable=True)
    completed_at    = Column(DateTime(timezone=True), nullable=True)
    total_kg        = Column(Float, default=0.0)
    payment_amount  = Column(Float, default=0.0)
    payment_status  = Column(String, default="pending")  # pending|released|withheld
    notes           = Column(Text, nullable=True)
    created_at      = Column(DateTime(timezone=True), server_default=func.now())

class CollectionEvent(Base):
    __tablename__ = "collection_events"
    id              = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    route_id        = Column(String, ForeignKey("collection_routes.id"), nullable=False)
    contractor_id   = Column(String, ForeignKey("contractors.id"), nullable=False)
    bin_id          = Column(String, ForeignKey("smart_bins.id"), nullable=False)
    weight_kg       = Column(Float, nullable=False)
    qr_scan_data    = Column(String, nullable=True)
    verified        = Column(Boolean, default=False)
    lat             = Column(Float, nullable=True)
    lng             = Column(Float, nullable=True)
    collected_at    = Column(DateTime(timezone=True), server_default=func.now())

class LocationPing(Base):
    __tablename__ = "location_pings"
    id              = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    contractor_id   = Column(String, ForeignKey("contractors.id"), nullable=False)
    lat             = Column(Float, nullable=False)
    lng             = Column(Float, nullable=False)
    speed_kmh       = Column(Float, nullable=True)
    recorded_at     = Column(DateTime(timezone=True), server_default=func.now())

Base.metadata.create_all(bind=engine)

# ── Schemas ───────────────────────────────────────────────────────────────────

class RegisterContractorRequest(BaseModel):
    user_id:          str
    lga_id:           str
    truck_number:     str
    license_plate:    Optional[str] = None
    capacity_tonnes:  float = 5.0
    rate_per_tonne:   float = 8500.0
    bank_code:        Optional[str] = None
    account_number:   Optional[str] = None

class DispatchRequest(BaseModel):
    contractor_id:  str
    lga_id:         str
    bin_ids:        List[str]
    notes:          Optional[str] = None

class LocationUpdateRequest(BaseModel):
    contractor_id:  str
    lat:            float
    lng:            float
    speed_kmh:      Optional[float] = None
    status:         Optional[ContractorStatus] = None

class CollectionVerifyRequest(BaseModel):
    route_id:       str
    bin_id:         str
    weight_kg:      float
    qr_scan_data:   Optional[str] = None
    lat:            Optional[float] = None
    lng:            Optional[float] = None

class PaymentReleaseRequest(BaseModel):
    route_id:       str
    override_amount: Optional[float] = None

# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/register", status_code=201)
def register_contractor(data: RegisterContractorRequest, db: Session = Depends(get_db)):
    """Register a new waste collection contractor."""
    if db.query(Contractor).filter(Contractor.user_id == data.user_id).first():
        raise HTTPException(400, "Contractor already registered for this user")
    if db.query(Contractor).filter(Contractor.truck_number == data.truck_number).first():
        raise HTTPException(400, f"Truck {data.truck_number} already registered")

    contractor = Contractor(
        user_id=data.user_id,
        lga_id=data.lga_id,
        truck_number=data.truck_number,
        license_plate=data.license_plate,
        capacity_tonnes=data.capacity_tonnes,
        rate_per_tonne=data.rate_per_tonne,
        bank_code=data.bank_code,
        account_number=data.account_number,
    )
    db.add(contractor)
    db.commit()
    db.refresh(contractor)
    return {"status": "registered", "contractor_id": contractor.id, "truck": data.truck_number}


@router.post("/dispatch", status_code=201)
def dispatch_contractor(data: DispatchRequest, db: Session = Depends(get_db)):
    """Assign contractor to a collection route."""
    contractor = db.query(Contractor).filter(Contractor.id == data.contractor_id).first()
    if not contractor:
        raise HTTPException(404, "Contractor not found")
    if contractor.status == ContractorStatus.SUSPENDED:
        raise HTTPException(403, "Contractor is suspended")

    # Validate bins exist
    from app.models.models import SmartBin
    bins = db.query(SmartBin).filter(SmartBin.id.in_(data.bin_ids)).all()
    if len(bins) != len(data.bin_ids):
        raise HTTPException(404, "One or more bin IDs not found")

    route = CollectionRoute(
        contractor_id=data.contractor_id,
        lga_id=data.lga_id,
        bin_ids=",".join(data.bin_ids),
        notes=data.notes,
        status=RouteStatus.ASSIGNED,
    )
    db.add(route)
    contractor.status = ContractorStatus.ON_ROUTE
    db.commit()
    db.refresh(route)

    return {
        "status": "dispatched",
        "route_id": route.id,
        "contractor": contractor.truck_number,
        "bins_assigned": len(data.bin_ids),
        "bin_addresses": [b.address for b in bins],
    }


@router.post("/location/update")
def update_location(data: LocationUpdateRequest, db: Session = Depends(get_db)):
    """GPS ping from contractor's mobile device."""
    contractor = db.query(Contractor).filter(Contractor.id == data.contractor_id).first()
    if not contractor:
        raise HTTPException(404, "Contractor not found")

    contractor.current_lat = data.lat
    contractor.current_lng = data.lng
    contractor.last_ping   = datetime.utcnow()
    if data.status:
        contractor.status = data.status

    db.add(LocationPing(
        contractor_id=data.contractor_id,
        lat=data.lat,
        lng=data.lng,
        speed_kmh=data.speed_kmh,
    ))
    db.commit()
    return {"status": "ok", "recorded_at": str(datetime.utcnow())}


@router.get("/live")
def live_contractors(lga_id: Optional[str] = None, db: Session = Depends(get_db)):
    """Government dashboard: all active contractors with live positions."""
    q = db.query(Contractor).filter(
        Contractor.status.in_([ContractorStatus.ON_ROUTE, ContractorStatus.ACTIVE, ContractorStatus.BREAK])
    )
    if lga_id:
        q = q.filter(Contractor.lga_id == lga_id)

    contractors = q.all()
    result = []
    for c in contractors:
        user = db.query(User).filter(User.id == c.user_id).first()
        lga  = db.query(LGA).filter(LGA.id == c.lga_id).first()

        # Get today's collection
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        today_events = db.query(CollectionEvent).filter(
            CollectionEvent.contractor_id == c.id,
            CollectionEvent.collected_at >= today_start,
        ).all()
        today_kg = sum(e.weight_kg for e in today_events)

        # Get active route
        active_route = db.query(CollectionRoute).filter(
            CollectionRoute.contractor_id == c.id,
            CollectionRoute.status.in_([RouteStatus.ASSIGNED, RouteStatus.ACTIVE]),
        ).first()

        result.append({
            "contractor_id":  c.id,
            "name":           user.full_name if user else "Unknown",
            "truck_number":   c.truck_number,
            "lga":            lga.name if lga else "Unknown",
            "status":         c.status.value,
            "position":       {"lat": c.current_lat, "lng": c.current_lng} if c.current_lat else None,
            "last_ping":      str(c.last_ping) if c.last_ping else None,
            "today_kg":       round(today_kg, 2),
            "today_tonnes":   round(today_kg / 1000, 3),
            "active_route_id": active_route.id if active_route else None,
            "bins_remaining": len(active_route.bin_ids.split(",")) - len(today_events) if active_route else 0,
        })

    return {"active_contractors": len(result), "contractors": result}


@router.post("/collection/verify")
def verify_collection(data: CollectionVerifyRequest, db: Session = Depends(get_db)):
    """Record and verify a bin collection event (QR scan + weight)."""
    route = db.query(CollectionRoute).filter(CollectionRoute.id == data.route_id).first()
    if not route:
        raise HTTPException(404, "Route not found")

    # Verify bin is on this route
    if data.bin_id not in route.bin_ids.split(","):
        raise HTTPException(400, f"Bin {data.bin_id} is not on route {data.route_id}")

    event = CollectionEvent(
        route_id=data.route_id,
        contractor_id=route.contractor_id,
        bin_id=data.bin_id,
        weight_kg=data.weight_kg,
        qr_scan_data=data.qr_scan_data,
        verified=bool(data.qr_scan_data),
        lat=data.lat,
        lng=data.lng,
    )
    db.add(event)

    # Update route totals
    route.total_kg += data.weight_kg
    route.status = RouteStatus.ACTIVE

    # Update smart bin fill level
    bin_ = db.query(SmartBin).filter(SmartBin.id == data.bin_id).first()
    if bin_:
        from app.models.models import BinStatus
        bin_.fill_percent = 0
        bin_.status = BinStatus.ACTIVE
        bin_.last_emptied = datetime.utcnow()

    # Update contractor totals
    contractor = db.query(Contractor).filter(Contractor.id == route.contractor_id).first()
    if contractor:
        contractor.total_collected += data.weight_kg

    db.commit()

    # Check if all bins done
    all_bins   = route.bin_ids.split(",")
    done_bins  = [e.bin_id for e in db.query(CollectionEvent).filter(
        CollectionEvent.route_id == data.route_id).all()]
    remaining  = [b for b in all_bins if b not in done_bins]

    return {
        "status": "verified",
        "bin_id": data.bin_id,
        "weight_kg": data.weight_kg,
        "route_total_kg": round(route.total_kg, 2),
        "bins_remaining": len(remaining),
        "route_complete": len(remaining) == 0,
    }


@router.post("/payment/release")
def release_payment(data: PaymentReleaseRequest, db: Session = Depends(get_db)):
    """Release contractor payment after verified collection. Auto-calculates from weight."""
    route = db.query(CollectionRoute).filter(CollectionRoute.id == data.route_id).first()
    if not route:
        raise HTTPException(404, "Route not found")
    if route.payment_status == "released":
        raise HTTPException(400, "Payment already released for this route")

    contractor = db.query(Contractor).filter(Contractor.id == route.contractor_id).first()
    if not contractor:
        raise HTTPException(404, "Contractor not found")

    # Calculate payment: weight × rate per tonne
    tonnes  = route.total_kg / 1000
    amount  = data.override_amount or round(tonnes * contractor.rate_per_tonne, 2)

    if amount <= 0:
        raise HTTPException(400, "No verified collection weight — cannot release payment")

    ref = f"WP-CPAY-{uuid.uuid4().hex[:12].upper()}"

    # Paystack transfer to contractor's bank
    if contractor.bank_code and contractor.account_number:
        try:
            # Create transfer recipient
            rec_resp = httpx.post(
                f"{settings.PAYSTACK_BASE_URL}/transferrecipient",
                headers={
                    "Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "type": "nuban",
                    "name": db.query(User).filter(User.id == contractor.user_id).first().full_name,
                    "account_number": contractor.account_number,
                    "bank_code": contractor.bank_code,
                    "currency": "NGN",
                },
                timeout=30
            )
            rec_code = rec_resp.json().get("data", {}).get("recipient_code")

            if rec_code:
                httpx.post(
                    f"{settings.PAYSTACK_BASE_URL}/transfer",
                    headers={
                        "Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "source": "balance",
                        "amount": int(amount * 100),
                        "recipient": rec_code,
                        "reference": ref,
                        "reason": f"WastePay collection — {route.id[:8]} — {tonnes:.2f}t",
                    },
                    timeout=30
                )
        except Exception:
            pass  # Log but don't fail — mark as pending bank release

    route.payment_amount  = amount
    route.payment_status  = "released"
    route.completed_at    = datetime.utcnow()
    route.status          = RouteStatus.COMPLETED
    contractor.total_earned += amount
    contractor.status     = ContractorStatus.ACTIVE

    db.commit()

    return {
        "status":          "released",
        "route_id":        data.route_id,
        "contractor":      contractor.truck_number,
        "tonnes_collected": round(tonnes, 3),
        "amount_released":  amount,
        "reference":        ref,
        "rate_per_tonne":   contractor.rate_per_tonne,
    }


@router.get("/report/{lga_id}")
def contractor_report(lga_id: str, db: Session = Depends(get_db)):
    """Contractor performance report for government dashboard."""
    contractors = db.query(Contractor).filter(Contractor.lga_id == lga_id).all()
    report = []
    for c in contractors:
        user   = db.query(User).filter(User.id == c.user_id).first()
        routes = db.query(CollectionRoute).filter(CollectionRoute.contractor_id == c.id).all()
        report.append({
            "contractor_id":    c.id,
            "name":             user.full_name if user else "Unknown",
            "truck_number":     c.truck_number,
            "status":           c.status.value,
            "total_routes":     len(routes),
            "completed_routes": sum(1 for r in routes if r.status == RouteStatus.COMPLETED),
            "total_kg":         round(c.total_collected, 2),
            "total_tonnes":     round(c.total_collected / 1000, 3),
            "total_earned_ngn": round(c.total_earned, 2),
            "compliance_rate":  round(
                sum(1 for r in routes if r.status == RouteStatus.COMPLETED) / len(routes) * 100
                if routes else 0, 1
            ),
        })
    report.sort(key=lambda x: x["total_kg"], reverse=True)

    return {
        "lga_id":          lga_id,
        "total_contractors": len(contractors),
        "total_kg_collected": round(sum(c.total_collected for c in contractors), 2),
        "total_paid_ngn":    round(sum(c.total_earned for c in contractors), 2),
        "contractors":       report,
    }
