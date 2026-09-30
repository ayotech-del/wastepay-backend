"""Persistent citizen operations and trusted HTTP telemetry ingestion."""
import math, hmac
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy import Column, String, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import Session
from app.core.database import Base, get_db
from app.core.core import settings
from app.core.permissions import StaffGrant, require_admin, check_lga
from app.models.models import User, LGA, SmartBin, BinStatus, WasteDeposit, WasteType, gen_id
from sqlalchemy.exc import IntegrityError
from app.routers.auth import get_current_user
users_router=APIRouter(); bins_router=APIRouter(); waste_router=APIRouter(); pickups_router=APIRouter()
class BinReading(Base):
    __tablename__='bin_readings'
    id=Column(String, primary_key=True, default=gen_id)
    bin_id=Column(String, ForeignKey('smart_bins.id'), nullable=False, index=True)
    weight_kg=Column(Float, nullable=False)
    recorded_at=Column(DateTime, nullable=False, default=datetime.utcnow)
    used=Column(Boolean, nullable=False, default=False)
class Pickup(Base):
    __tablename__='pickup_requests'
    id=Column(String, primary_key=True, default=gen_id)
    user_id=Column(String, ForeignKey('users.id'), nullable=False)
    address=Column(String(500), nullable=False)
    notes=Column(String(1000))
    status=Column(String, nullable=False, default='requested')
    created_at=Column(DateTime, default=datetime.utcnow)
class Input(BaseModel):
    model_config=ConfigDict(allow_inf_nan=False)
class Telemetry(Input):
    bin_code: str
    weight_kg: float=Field(ge=0, le=100000)
    fill_percent: int=Field(ge=0, le=100)
class Deposit(Input):
    waste_type: WasteType
    weight_kg: float=Field(gt=0, le=10000)
    bin_id: str
    qr_scan_data: str | None=None
class PickupInput(Input):
    address: str=Field(min_length=5,max_length=500)
    notes: str=Field(default='',max_length=1000)

class BinInput(Input):
    model_config=ConfigDict(allow_inf_nan=False, str_strip_whitespace=True)
    bin_code: str=Field(min_length=1,max_length=20)
    address: str=Field(min_length=5,max_length=500)
    latitude: float=Field(ge=-90,le=90)
    longitude: float=Field(ge=-180,le=180)
    lga_id: str=Field(min_length=1)

def bin_details(b):
    return {'id':b.id,'bin_code':b.bin_code,'latitude':b.latitude,'longitude':b.longitude,
            'address':b.address,'lga_id':b.lga_id,'fill_percent':b.fill_percent,'status':b.status.value}

@bins_router.post('',status_code=201)
def create_bin(data:BinInput,grant=Depends(require_admin),db:Session=Depends(get_db)):
    check_lga(grant,data.lga_id)
    if not db.get(LGA,data.lga_id): raise HTTPException(404,'LGA not found')
    if db.query(SmartBin).filter_by(bin_code=data.bin_code).first():
        raise HTTPException(409,'Bin code already registered')
    b=SmartBin(**data.model_dump());db.add(b)
    try: db.commit()
    except IntegrityError:
        db.rollback();raise HTTPException(409,'Bin code already registered')
    db.refresh(b)
    return bin_details(b)

@bins_router.get('')
def list_bins(lga_id:str,grant=Depends(require_admin),db:Session=Depends(get_db)):
    check_lga(grant,lga_id)
    return [bin_details(b) for b in db.query(SmartBin).filter_by(lga_id=lga_id).order_by(SmartBin.bin_code).all()]

@bins_router.get('/lookup')
def lookup_bin(identifier:str,db:Session=Depends(get_db)):
    identifier=identifier.strip()
    b=db.query(SmartBin).filter_by(bin_code=identifier).first() or db.get(SmartBin,identifier)
    if not b: raise HTTPException(404,'Bin not found. Check the printed code or bin ID.')
    return bin_details(b)
def distance_m(lat,lng,lat2,lng2):
    a,b=math.radians(lat),math.radians(lat2)
    dlat=math.radians(lat2-lat); dlng=math.radians(lng2-lng)
    x=math.sin(dlat/2)**2+math.cos(a)*math.cos(b)*math.sin(dlng/2)**2
    return 6371000*2*math.asin(math.sqrt(min(1,x)))
@users_router.get('/me')
def me(user=Depends(get_current_user),db:Session=Depends(get_db)):
    grant=db.get(StaffGrant,user.id)
    return {'id':user.id,'phone':user.phone,'email':user.email,'full_name':user.full_name,
            'kyc_tier':user.kyc_tier.value,'lga_id':user.lga_id,
            'role':grant.role if grant else ('contractor' if user.is_collector else 'citizen')}
@users_router.post('/kyc/nin')
@users_router.post('/kyc/bvn')
def unavailable_kyc(user=Depends(get_current_user)):
    raise HTTPException(503,'Identity verification provider is not configured')
@bins_router.get('/nearby')
def nearby(lat:float=0,lng:float=0,radius_km:float=3,db:Session=Depends(get_db)):
    if not math.isfinite(radius_km) or not 0<radius_km<=50 or not -90<=lat<=90 or not -180<=lng<=180:
        raise HTTPException(422,'Invalid search coordinates or radius (max 50km)')
    out=[]
    for b in db.query(SmartBin).all():
        distance=distance_m(lat,lng,b.latitude,b.longitude)/1000
        if distance<=radius_km:
            out.append({'id':b.id,'bin_code':b.bin_code,'latitude':b.latitude,'longitude':b.longitude,
                        'address':b.address,'fill_percent':b.fill_percent,'status':b.status.value,'distance_km':round(distance,3)})
    return sorted(out,key=lambda b:b['distance_km'])
@bins_router.post('/telemetry')
def telemetry(data:Telemetry,x_telemetry_key:str=Header(default=''),db:Session=Depends(get_db)):
    if not settings.TELEMETRY_KEY: raise HTTPException(503,'Telemetry bridge not configured')
    if not hmac.compare_digest(x_telemetry_key,settings.TELEMETRY_KEY): raise HTTPException(401,'Invalid telemetry credential')
    b=db.query(SmartBin).filter_by(bin_code=data.bin_code).first()
    if not b: raise HTTPException(404,'Bin not found')
    b.fill_percent=data.fill_percent; b.last_telemetry=datetime.utcnow()
    b.status=BinStatus.FULL if data.fill_percent>=75 else BinStatus.ACTIVE
    r=BinReading(bin_id=b.id,weight_kg=data.weight_kg);db.add(r);db.commit()
    return {'status':'recorded','reading_id':r.id,'collection_alert':data.fill_percent>=75}
@bins_router.get('/{bin_code}/status')
def bin_status(bin_code:str,db:Session=Depends(get_db)):
    b=db.query(SmartBin).filter_by(bin_code=bin_code).first()
    if not b: raise HTTPException(404,'Bin not found')
    return {'bin_code':b.bin_code,'fill_percent':b.fill_percent,'status':b.status.value,'last_telemetry':b.last_telemetry}
@waste_router.get('/rates')
def rates():
    return {'rates_ngn_per_kg':{t.value:getattr(settings,'RATE_'+t.value.upper()) for t in WasteType}}
@waste_router.post('/deposit')
def deposit(data:Deposit,user=Depends(get_current_user),db:Session=Depends(get_db)):
    if not db.get(SmartBin,data.bin_id): raise HTTPException(404,'Bin not found')
    d=WasteDeposit(user_id=user.id,bin_id=data.bin_id,waste_type=data.waste_type,weight_kg=data.weight_kg,
                   credit_value=0,verified=False,qr_scan_data=data.qr_scan_data)
    db.add(d);db.commit()
    return {'deposit_id':d.id,'status':'pending_verification','credit_value':0,
            'message':'Deposit submitted for verification. Credits have not been awarded.'}
@waste_router.get('/history')
def history(user=Depends(get_current_user),db:Session=Depends(get_db)):
    return [{'id':d.id,'weight_kg':d.weight_kg,'waste_type':d.waste_type.value,'verified':d.verified,'credit_value':d.credit_value}
            for d in db.query(WasteDeposit).filter_by(user_id=user.id).order_by(WasteDeposit.created_at.desc()).limit(100)]
@pickups_router.post('',status_code=201)
def pickup(data:PickupInput,user=Depends(get_current_user),db:Session=Depends(get_db)):
    p=Pickup(user_id=user.id,**data.model_dump());db.add(p);db.commit()
    return {'id':p.id,'status':p.status}
@pickups_router.get('')
def pickups(user=Depends(get_current_user),db:Session=Depends(get_db)):
    return [{'id':p.id,'address':p.address,'notes':p.notes,'status':p.status,'created_at':p.created_at}
            for p in db.query(Pickup).filter_by(user_id=user.id).order_by(Pickup.created_at.desc()).limit(100)]

@waste_router.post('/deposit/{deposit_id}/verify')
def verify_deposit(deposit_id:str,grant=Depends(require_admin),db:Session=Depends(get_db)):
    from sqlalchemy import update
    from app.models.models import Wallet,Transaction,TransactionType
    d=db.query(WasteDeposit).filter_by(id=deposit_id).with_for_update().first()
    if not d: raise HTTPException(404,'Deposit not found')
    if d.verified: raise HTTPException(409,'Deposit already verified')
    b=db.get(SmartBin,d.bin_id)
    check_lga(grant,b.lga_id)
    if d.qr_scan_data!=b.bin_code: raise HTTPException(422,'QR code must match the bin')
    readings=db.query(BinReading).filter_by(bin_id=b.id).order_by(BinReading.recorded_at.desc()).limit(2).all()
    if len(readings)!=2: raise HTTPException(422,'Two trusted sensor readings required')
    after,before=readings
    if (datetime.utcnow()-after.recorded_at).total_seconds()>300 or (after.recorded_at-before.recorded_at).total_seconds()>600:
        raise HTTPException(422,'Sensor readings are stale')
    kg=round(after.weight_kg-before.weight_kg,3)
    if kg<=0 or abs(kg-d.weight_kg)>max(0.1,d.weight_kg*0.05):
        raise HTTPException(422,'Sensor weight does not match the deposit')
    claimed=db.execute(update(BinReading).where(BinReading.id==after.id,BinReading.used==False).values(used=True))
    if claimed.rowcount!=1: raise HTTPException(409,'Sensor reading already used')
    credit=round(kg*getattr(settings,'RATE_'+d.waste_type.value.upper()),2)
    credited=db.execute(update(Wallet).where(Wallet.user_id==d.user_id).values(eco_credits=Wallet.eco_credits+credit,
        total_earned=Wallet.total_earned+credit,kg_deposited=Wallet.kg_deposited+kg))
    if credited.rowcount!=1: raise HTTPException(409,'Wallet missing')
    d.verified=True;d.credit_value=credit;d.weight_kg=kg;d.notes=f'Verified by {grant.user_id}; reading {after.id}'
    db.add(Transaction(user_id=d.user_id,type=TransactionType.CREDIT_EARNED,amount=credit,
        reference='DEPOSIT-'+d.id,status='success',description=f'{kg}kg {d.waste_type.value} verified'))
    db.commit()
    return {'status':'verified','credit_value':credit,'weight_kg':kg}
