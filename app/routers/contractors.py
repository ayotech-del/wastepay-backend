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
from sqlalchemy import UniqueConstraint, Column, String, Float, Integer, Boolean, DateTime, Enum, ForeignKey, Text
from sqlalchemy.sql import func
from pydantic import BaseModel, Field
from typing import Optional, List
import uuid, enum
from datetime import datetime

from app.core.core import get_db, settings
from app.core.database import Base, engine
from app.models.models import User, LGA, SmartBin, Transaction, TransactionType, Wallet
from app.routers.auth import get_current_user
from app.core.permissions import require_admin, require_operations, require_finance, check_lga, allowed_lgas, ensure_driver, audit, get_access, Access, ROLE_PERMISSIONS
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
    __table_args__ = (UniqueConstraint("route_id", "bin_id", name="uq_route_bin"),)
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



# ── Schemas ───────────────────────────────────────────────────────────────────

class RegisterContractorRequest(BaseModel):
    user_id:          str
    lga_id:           str
    truck_number:     str
    license_plate:    Optional[str] = None
    capacity_tonnes:  float = Field(default=5.0, gt=0, le=100)
    rate_per_tonne:   float = Field(default=8500.0, gt=0, le=10000000)
    bank_code:        Optional[str] = None
    account_number:   Optional[str] = None

class DispatchRequest(BaseModel):
    contractor_id:  str
    lga_id:         str
    bin_ids:        List[str]
    notes:          Optional[str] = None

class LocationUpdateRequest(BaseModel):
    contractor_id:  str
    lat:            float = Field(ge=-90, le=90)
    lng:            float = Field(ge=-180, le=180)
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
def register_contractor(data: RegisterContractorRequest, grant=Depends(require_operations), db: Session = Depends(get_db)):
    check_lga(grant, data.lga_id)
    if data.rate_per_tonne!=8500 or data.bank_code or data.account_number:
        current=get_access(db.get(User,grant.user_id),db)
        financial=Access(grant.user_id,[g for g in current.grants if 'government.finance' in ROLE_PERMISSIONS.get(g.role,set())],db)
        check_lga(financial,data.lga_id)
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
    user = db.get(User, data.user_id)
    if not user or not db.get(LGA, data.lga_id): raise HTTPException(404,"User or LGA not found")
    user.is_collector = True
    db.add(contractor)
    db.commit()
    db.refresh(contractor)
    return {"status": "registered", "contractor_id": contractor.id, "truck": data.truck_number}


@router.post("/dispatch", status_code=201)
def dispatch_contractor(data: DispatchRequest, grant=Depends(require_operations), db: Session = Depends(get_db)):
    check_lga(grant, data.lga_id)
    if not data.bin_ids or len(data.bin_ids) != len(set(data.bin_ids)):
        raise HTTPException(422, "Supply distinct bin IDs")
    """Assign contractor to a collection route."""
    contractor = db.query(Contractor).filter(Contractor.id == data.contractor_id).first()
    if not contractor:
        raise HTTPException(404, "Contractor not found")
    if contractor.status == ContractorStatus.SUSPENDED:
        raise HTTPException(403, "Contractor is suspended")

    if contractor.lga_id != data.lga_id:
        raise HTTPException(400, "Contractor LGA mismatch")
    # Validate bins exist
    from app.models.models import SmartBin
    bins = db.query(SmartBin).filter(SmartBin.id.in_(data.bin_ids)).all()
    if len(bins) != len(data.bin_ids):
        raise HTTPException(404, "One or more bin IDs not found")

    if any(b.lga_id != data.lga_id for b in bins):
        raise HTTPException(400, "Bin LGA mismatch")
    route = CollectionRoute(
        contractor_id=data.contractor_id,
        lga_id=data.lga_id,
        bin_ids=",".join(data.bin_ids),
        notes=data.notes,
        status=RouteStatus.ASSIGNED,
    )
    membership=ensure_driver(contractor,contractor.user_id,db)
    db.add(route);db.flush()
    if membership:
        from app.models.access import Vehicle,RouteAssignment,CollectionJob
        from app.routers.organizations import validate_area
        validate_area(db,membership.company_id,data.lga_id)
        vehicle=db.query(Vehicle).filter_by(driver_id=membership.id,active=True).one()
        db.add(RouteAssignment(route_id=route.id,company_id=membership.company_id,vehicle_id=vehicle.id))
        for bin_id in data.bin_ids:db.add(CollectionJob(route_id=route.id,company_id=membership.company_id,bin_id=bin_id))
    audit(db,grant.user_id,'route.assigned',route.id,lga_id=route.lga_id,
        company_id=membership.company_id if membership else None,details={'contractor_id':contractor.id})
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
def update_location(data: LocationUpdateRequest, user=Depends(get_current_user), db: Session = Depends(get_db)):
    """GPS ping from contractor's mobile device."""
    contractor = db.query(Contractor).filter(Contractor.id == data.contractor_id).first()
    if not contractor:
        raise HTTPException(404, "Contractor not found")

    ensure_driver(contractor,user.id,db)
    if data.status == ContractorStatus.SUSPENDED:
        raise HTTPException(403, "Invalid status transition")
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
def live_contractors(lga_id: Optional[str] = None, grant=Depends(require_admin), db: Session = Depends(get_db)):
    if lga_id:check_lga(grant,lga_id)
    area_ids=allowed_lgas(grant,db)
    """Government dashboard: all active contractors with live positions."""
    q = db.query(Contractor).filter(Contractor.lga_id.in_(area_ids),
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


@router.get("/my-routes")
def my_routes(user=Depends(get_current_user), db: Session=Depends(get_db)):
    contractor = db.query(Contractor).filter_by(user_id=user.id).first()
    ensure_driver(contractor,user.id,db)
    from app.models.access import CollectionJob
    from app.routers.organizations import job_out
    return [{"id":r.id, "status":r.status.value, "bin_ids":r.bin_ids.split(","), "total_kg":r.total_kg,
             "jobs":[job_out(db,j,False) for j in db.query(CollectionJob).filter_by(route_id=r.id)]}
            for r in db.query(CollectionRoute).filter_by(contractor_id=contractor.id).all()]

@router.post("/collection/verify")
def verify_collection(data: CollectionVerifyRequest, user=Depends(get_current_user), db: Session=Depends(get_db)):
    from app.routers.operations import BinReading, distance_m
    from sqlalchemy import update
    route = db.query(CollectionRoute).filter_by(id=data.route_id).with_for_update().first()
    if not route: raise HTTPException(404, "Route not found")
    contractor = db.get(Contractor, route.contractor_id)
    ensure_driver(contractor,user.id,db)
    if route.status not in (RouteStatus.ASSIGNED, RouteStatus.ACTIVE): raise HTTPException(409, "Route is closed")
    if data.bin_id not in route.bin_ids.split(","): raise HTTPException(400, "Bin not assigned")
    if db.query(CollectionEvent).filter_by(route_id=route.id, bin_id=data.bin_id).first():
        raise HTTPException(409, "Bin already collected on this route")
    from app.models.access import CollectionJob
    job=db.query(CollectionJob).filter_by(route_id=route.id,bin_id=data.bin_id).first()
    if job and job.status in ('missed','cancelled'):raise HTTPException(409,'Dispatcher must reassign this missed or cancelled job')
    bin_ = db.get(SmartBin, data.bin_id)
    if data.qr_scan_data != bin_.bin_code: raise HTTPException(422, "QR must match bin code")
    if data.lat is None or data.lng is None or not (-90 <= data.lat <= 90 and -180 <= data.lng <= 180):
        raise HTTPException(422, "Valid GPS position required")
    if distance_m(data.lat, data.lng, bin_.latitude, bin_.longitude) > 100:
        raise HTTPException(422, "Outside 100 metre collection radius")
    readings = db.query(BinReading).filter_by(bin_id=bin_.id).order_by(BinReading.recorded_at.desc()).limit(2).all()
    if len(readings) != 2: raise HTTPException(422, "Two trusted sensor readings required")
    after, before = readings
    if (datetime.utcnow() - after.recorded_at.replace(tzinfo=None)).total_seconds() > 300 or (after.recorded_at-before.recorded_at).total_seconds() > 600:
        raise HTTPException(422, "Sensor readings are stale")
    kg = round(before.weight_kg - after.weight_kg, 3)
    if kg <= 0: raise HTTPException(422, "Sensor has not confirmed weight removal")
    claimed = db.execute(update(BinReading).where(BinReading.id==after.id, BinReading.used==False).values(used=True))
    if claimed.rowcount != 1: raise HTTPException(409, "Sensor reading already used")
    event = CollectionEvent(route_id=route.id, contractor_id=contractor.id, bin_id=bin_.id,
        weight_kg=kg, qr_scan_data=data.qr_scan_data, verified=True, lat=data.lat, lng=data.lng)
    db.add(event)
    route.total_kg += kg; route.status = RouteStatus.ACTIVE
    contractor.total_collected += kg
    db.flush()
    count = db.query(CollectionEvent).filter_by(route_id=route.id, verified=True).count()
    if job:
        from app.routers.operations import Pickup
        job.status='collected_verified';job.verified_at=datetime.utcnow()
        if job.pickup_id:db.get(Pickup,job.pickup_id).status='collected_verified'
    if count==len(route.bin_ids.split(',')):
        route.status=RouteStatus.COMPLETED;route.completed_at=datetime.utcnow()
    audit(db,user.id,'collection.verified',job.id if job else event.id,lga_id=route.lga_id,
        company_id=job.company_id if job else None,details={'weight_kg':kg,'route_id':route.id})
    db.commit()
    return {"status":"verified", "weight_kg":kg, "route_total_kg":route.total_kg,
            "bins_remaining":len(route.bin_ids.split(","))-count, "route_complete":count==len(route.bin_ids.split(","))}

@router.post("/payment/release")
def release_payment(data: PaymentReleaseRequest, grant=Depends(require_finance), db: Session=Depends(get_db)):
    route = db.query(CollectionRoute).filter_by(id=data.route_id).with_for_update().first()
    if not route: raise HTTPException(404, "Route not found")
    check_lga(grant, route.lga_id)
    events = db.query(CollectionEvent).filter_by(route_id=route.id, verified=True).all()
    if set(e.bin_id for e in events) != set(route.bin_ids.split(",")):
        raise HTTPException(409, "All assigned bins require verified collections")
    if data.override_amount is not None: raise HTTPException(422, "Amount is calculated from verified weight")
    if route.payment_status != "pending": raise HTTPException(409, "Payment already authorized")
    contractor = db.get(Contractor, route.contractor_id)
    route.payment_amount = round(sum(e.weight_kg for e in events)/1000*contractor.rate_per_tonne, 2)
    route.payment_status = "awaiting_disbursement"
    route.status = RouteStatus.COMPLETED; route.completed_at = datetime.utcnow()
    from app.models.access import RouteAssignment
    assignment=db.get(RouteAssignment,route.id)
    audit(db,grant.user_id,'settlement.authorized',route.id,lga_id=route.lga_id,
        company_id=assignment.company_id if assignment else None,details={'amount_ngn':route.payment_amount})
    db.commit()
    return {"status":"awaiting_disbursement", "route_id":route.id, "amount_ngn":route.payment_amount,
            "message":"Authorized only; no bank transfer has occurred"}

@router.get("/report/{lga_id}")
def contractor_report(lga_id: str, grant=Depends(require_admin), db: Session = Depends(get_db)):
    check_lga(grant, lga_id)
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

@router.get("/me")
def my_contractor(user=Depends(get_current_user),db:Session=Depends(get_db)):
    c=db.query(Contractor).filter_by(user_id=user.id).first()
    ensure_driver(c,user.id,db)
    return {"id":c.id,"truck_number":c.truck_number,"status":c.status.value}
