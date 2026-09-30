"""Company-scoped fleet, collection jobs and consumer service relationships."""
from datetime import datetime
from typing import Literal
from fastapi import APIRouter,Depends,HTTPException
from pydantic import BaseModel,Field,ConfigDict
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from app.core.database import get_db
from app.core.permissions import (get_access,require_operations,require_admin,company_access,allowed_lgas,
    check_lga,audit,ROLE_PERMISSIONS,Access,ensure_driver)
from app.models.models import User,LGA,SmartBin,gen_id
from app.models.access import (Company,CompanyArea,CompanyDriver,Vehicle,RoleGrant,RouteAssignment,
    ServiceContract,ServiceInvoice,CollectionJob,AuditEvent,PickupContract)
from app.routers.contractors import Contractor,ContractorStatus,CollectionRoute,RouteStatus,CollectionEvent,LocationPing
from app.routers.billing import Invoice,inv_out
from app.routers.operations import Pickup
from app.routers.auth import get_current_user
router=APIRouter()

class Input(BaseModel):
    model_config=ConfigDict(str_strip_whitespace=True,allow_inf_nan=False)
class CompanyInput(Input):
    name:str=Field(min_length=2,max_length=200)
    lga_ids:list[str]=Field(min_length=1,max_length=100)
    manager_user_id:str
class VehicleInput(Input):
    truck_number:str=Field(min_length=1,max_length=20)
    license_plate:str|None=Field(default=None,max_length=20)
    capacity_tonnes:float=Field(default=5,gt=0,le=100)
class DriverInput(Input):
    user_id:str
    vehicle_id:str
    lga_id:str
class ActiveInput(Input):
    active:bool
class ContractInput(Input):
    company_id:str
    user_id:str
    lga_id:str
    household_ref:str=Field(min_length=1,max_length=80)
    address:str=Field(min_length=5,max_length=500)
    bin_id:str
class StopInput(Input):
    bin_id:str
    contract_id:str|None=None
    invoice_id:str|None=None
    pickup_id:str|None=None
class RouteInput(Input):
    driver_id:str
    lga_id:str
    stops:list[StopInput]=Field(min_length=1,max_length=200)
    notes:str=Field(default='',max_length=1000)
class ReassignInput(Input):
    driver_id:str
class JobStatusInput(Input):
    status:Literal['en_route','evidence_submitted','missed']
    reason:str=Field(default='',max_length=1000)
class ReportInput(Input):
    reason:str=Field(min_length=5,max_length=1000)

def company_areas(db,company_id):return [r.lga_id for r in db.query(CompanyArea).filter_by(company_id=company_id)]
def validate_area(db,company_id,lga_id):
    if lga_id not in company_areas(db,company_id):raise HTTPException(403,'Company is not approved in this LGA')
def company_scope(company_id,access,write=False):
    permission='company.manage' if write else 'company.view'
    try:
        company=company_access(company_id,access,permission)
        return company,set(company_areas(access.db,company_id))
    except HTTPException:
        wanted='government.operations' if write else 'government.view'
        scoped=Access(access.user_id,[g for g in access.grants if wanted in ROLE_PERMISSIONS.get(g.role,set())],access.db)
        areas=set(company_areas(access.db,company_id));allowed=set(allowed_lgas(scoped,access.db))
        company=access.db.get(Company,company_id)
        if not company or not company.active or not areas.intersection(allowed):raise HTTPException(403,'Outside your company or government area')
        if write and not areas.issubset(allowed):raise HTTPException(403,'All company areas require your operations permission')
        return company,areas.intersection(allowed)
def flush(db):
    try:db.flush()
    except IntegrityError:
        db.rollback();raise HTTPException(409,'Duplicate record or conflicting assignment')
def commit(db):
    try:db.commit()
    except IntegrityError:
        db.rollback();raise HTTPException(409,'Duplicate record or conflicting assignment')
def company_out(db,c,areas=None):
    return {'id':c.id,'name':c.name,'active':c.active,'lga_ids':sorted(areas if areas is not None else company_areas(db,c.id))}
def driver_out(db,m):
    c=db.get(Contractor,m.contractor_id);u=db.get(User,c.user_id)
    v=db.query(Vehicle).filter_by(driver_id=m.id).first()
    age=max(0,(datetime.utcnow()-c.last_ping.replace(tzinfo=None)).total_seconds()) if c.last_ping else None
    return {'id':m.id,'user_id':c.user_id,'name':u.full_name,'contractor_id':c.id,'lga_id':c.lga_id,
        'active':m.active,'vehicle_id':v.id if v else None,'truck_number':v.truck_number if v else c.truck_number,
        'status':c.status.value,'position':{'lat':c.current_lat,'lng':c.current_lng} if c.current_lat is not None else None,
        'last_ping':str(c.last_ping) if c.last_ping else None,'gps_age_seconds':round(age) if age is not None else None,
        'gps_stale':age is None or age>90}
def contract_out(db,c):
    company=db.get(Company,c.company_id);b=db.get(SmartBin,c.bin_id)
    return {'id':c.id,'company_id':c.company_id,'company':company.name,'user_id':c.user_id,'lga_id':c.lga_id,
        'household_ref':c.household_ref,'address':c.address,'bin_id':c.bin_id,'bin_code':b.bin_code,'active':c.active}
def job_out(db,j,include_finance=True):
    route=db.get(CollectionRoute,j.route_id);b=db.get(SmartBin,j.bin_id);driver=db.get(Contractor,route.contractor_id)
    user=db.get(User,driver.user_id);contract=db.get(ServiceContract,j.contract_id) if j.contract_id else None
    out={'id':j.id,'route_id':j.route_id,'bin_id':j.bin_id,'bin_code':b.bin_code,'address':contract.address if contract else b.address,
        'latitude':b.latitude,'longitude':b.longitude,'driver':user.full_name,'driver_id':driver.id,
        'collection_status':j.status,'missed_reason':j.missed_reason,'verified_at':str(j.verified_at) if j.verified_at else None,
        'household_ref':contract.household_ref if contract else None,'pickup_id':j.pickup_id}
    if include_finance:
        inv=db.get(Invoice,j.invoice_id) if j.invoice_id else None
        out['invoice']=inv_out(inv) if inv else None
        out['payment_status']=inv.status.value if inv else 'not_linked'
        out['settlement_status']=route.payment_status
    return out

@router.get('/companies')
def companies(access=Depends(get_access),db:Session=Depends(get_db)):
    rows=[]
    for c in db.query(Company).filter_by(active=True):
        try:_,areas=company_scope(c.id,access)
        except HTTPException:continue
        rows.append(company_out(db,c,areas))
    if not rows and not any('company.view' in ROLE_PERMISSIONS.get(g.role,set()) or 'government.view' in ROLE_PERMISSIONS.get(g.role,set()) for g in access.grants):
        raise HTTPException(403,'Company manager or government access required')
    return rows
@router.post('/companies',status_code=201)
def create_company(data:CompanyInput,access=Depends(require_operations),db:Session=Depends(get_db)):
    if len(data.lga_ids)!=len(set(data.lga_ids)):raise HTTPException(422,'Supply distinct LGAs')
    for lga_id in data.lga_ids:
        check_lga(access,lga_id)
        if not db.get(LGA,lga_id):raise HTTPException(404,'LGA not found')
    if not db.get(User,data.manager_user_id):raise HTTPException(404,'Registered manager not found')
    c=Company(name=data.name);db.add(c);db.flush()
    for lga_id in data.lga_ids:db.add(CompanyArea(company_id=c.id,lga_id=lga_id))
    db.add(RoleGrant(user_id=data.manager_user_id,role='contractor_manager',scope_kind='company',scope_value=c.id))
    audit(db,access.user_id,'company.approved',c.id,company_id=c.id,details=data.model_dump());commit(db)
    return company_out(db,c)
@router.post('/companies/{company_id}/vehicles',status_code=201)
def create_vehicle(company_id:str,data:VehicleInput,access=Depends(get_access),db:Session=Depends(get_db)):
    company_scope(company_id,access,True)
    if db.query(Contractor).filter_by(truck_number=data.truck_number).first():raise HTTPException(409,'Truck is already assigned to a legacy driver')
    v=Vehicle(company_id=company_id,**data.model_dump());db.add(v);flush(db)
    audit(db,access.user_id,'vehicle.created',v.id,company_id=company_id,details={'truck_number':v.truck_number});commit(db)
    return {'id':v.id,'truck_number':v.truck_number}
@router.post('/companies/{company_id}/drivers',status_code=201)
def create_driver(company_id:str,data:DriverInput,access=Depends(get_access),db:Session=Depends(get_db)):
    company_scope(company_id,access,True);validate_area(db,company_id,data.lga_id)
    v=db.query(Vehicle).filter_by(id=data.vehicle_id,company_id=company_id,active=True).with_for_update().first()
    if not v:raise HTTPException(404,'Company vehicle not found')
    if v.driver_id:raise HTTPException(409,'Vehicle already assigned')
    user=db.get(User,data.user_id)
    if not user:raise HTTPException(404,'Registered driver user not found')
    if db.query(Contractor).filter_by(user_id=data.user_id).first():raise HTTPException(409,'Driver already registered; legacy drivers remain available through their existing routes')
    c=Contractor(user_id=data.user_id,lga_id=data.lga_id,truck_number=v.truck_number,license_plate=v.license_plate,capacity_tonnes=v.capacity_tonnes)
    db.add(c);db.flush();m=CompanyDriver(company_id=company_id,contractor_id=c.id);db.add(m);db.flush()
    v.driver_id=m.id;user.is_collector=True
    db.add(RoleGrant(user_id=user.id,role='driver',scope_kind='company',scope_value=company_id))
    audit(db,access.user_id,'driver.registered',m.id,company_id=company_id,lga_id=data.lga_id,details={'user_id':user.id,'vehicle_id':v.id});commit(db)
    return driver_out(db,m)
@router.patch('/companies/{company_id}/drivers/{driver_id}')
def activate_driver(company_id:str,driver_id:str,data:ActiveInput,access=Depends(get_access),db:Session=Depends(get_db)):
    company_scope(company_id,access,True)
    m=db.query(CompanyDriver).filter_by(id=driver_id,company_id=company_id).first()
    if not m:raise HTTPException(404,'Company driver not found')
    c=db.get(Contractor,m.contractor_id);m.active=data.active
    for g in db.query(RoleGrant).filter_by(user_id=c.user_id,role='driver',scope_kind='company',scope_value=company_id):g.active=data.active
    audit(db,access.user_id,'driver.activated' if data.active else 'driver.revoked',m.id,company_id=company_id,lga_id=c.lga_id);commit(db)
    return driver_out(db,m)
@router.get('/companies/{company_id}/dashboard')
def dashboard(company_id:str,access=Depends(get_access),db:Session=Depends(get_db)):
    c,areas=company_scope(company_id,access)
    drivers=[m for m in db.query(CompanyDriver).filter_by(company_id=company_id) if db.get(Contractor,m.contractor_id).lga_id in areas]
    jobs=db.query(CollectionJob).join(CollectionRoute,CollectionJob.route_id==CollectionRoute.id).filter(CollectionJob.company_id==company_id,CollectionRoute.lga_id.in_(areas)).all()
    contracts=db.query(ServiceContract).filter(ServiceContract.company_id==company_id,ServiceContract.lga_id.in_(areas)).all()
    invoices=db.query(Invoice).join(ServiceInvoice,Invoice.id==ServiceInvoice.invoice_id).join(ServiceContract,ServiceInvoice.contract_id==ServiceContract.id).filter(ServiceContract.company_id==company_id,ServiceContract.lga_id.in_(areas)).all()
    vehicles=db.query(Vehicle).filter_by(company_id=company_id).all()
    routes=db.query(CollectionRoute).join(RouteAssignment,CollectionRoute.id==RouteAssignment.route_id).filter(RouteAssignment.company_id==company_id,CollectionRoute.lga_id.in_(areas)).all()
    requests=db.query(Pickup).join(PickupContract,Pickup.id==PickupContract.pickup_id).join(ServiceContract,PickupContract.contract_id==ServiceContract.id).filter(ServiceContract.company_id==company_id,ServiceContract.lga_id.in_(areas)).all()
    try:company_scope(company_id,access,True);manage_allowed=True
    except HTTPException:manage_allowed=False
    return {'company':company_out(db,c,areas),'manage_allowed':manage_allowed,'drivers':[driver_out(db,m) for m in drivers],
        'vehicles':[{'id':v.id,'truck_number':v.truck_number,'driver_id':v.driver_id,'active':v.active} for v in vehicles if v.driver_id is None or any(m.id==v.driver_id for m in drivers)],
        'routes':[{'id':r.id,'status':r.status.value,'contractor_id':r.contractor_id,'lga_id':r.lga_id,'payment_status':r.payment_status} for r in routes],
        'jobs':[job_out(db,j) for j in jobs],'contracts':[contract_out(db,s) for s in contracts],
        'invoices':[{**inv_out(i),'contract_id':db.get(ServiceInvoice,i.id).contract_id} for i in invoices],
        'pickup_requests':[{'id':p.id,'address':p.address,'notes':p.notes,'status':p.status,'contract_id':db.get(PickupContract,p.id).contract_id} for p in requests]}

@router.post('/contracts',status_code=201)
def create_contract(data:ContractInput,access=Depends(require_operations),db:Session=Depends(get_db)):
    check_lga(access,data.lga_id);validate_area(db,data.company_id,data.lga_id)
    c=db.get(Company,data.company_id);b=db.get(SmartBin,data.bin_id)
    if not c or not c.active or not db.get(User,data.user_id):raise HTTPException(404,'Active company or consumer not found')
    if not b or b.lga_id!=data.lga_id:raise HTTPException(422,'Bin must belong to the contract LGA')
    s=ServiceContract(**data.model_dump());db.add(s);flush(db)
    audit(db,access.user_id,'service.created',s.id,lga_id=s.lga_id,company_id=s.company_id,details={'user_id':s.user_id});commit(db)
    return contract_out(db,s)
@router.get('/contracts/mine')
def my_contracts(access=Depends(get_access),db:Session=Depends(get_db)):
    return [contract_out(db,s) for s in db.query(ServiceContract).filter_by(user_id=access.user_id,active=True)]
@router.get('/jobs/mine')
def my_jobs(access=Depends(get_access),db:Session=Depends(get_db)):
    rows=db.query(CollectionJob).join(ServiceContract,CollectionJob.contract_id==ServiceContract.id).filter(ServiceContract.user_id==access.user_id).all()
    return [job_out(db,j) for j in rows]
@router.post('/jobs/{job_id}/report',status_code=201)
def report_job(job_id:str,data:ReportInput,access=Depends(get_access),db:Session=Depends(get_db)):
    j=db.get(CollectionJob,job_id);s=db.get(ServiceContract,j.contract_id) if j and j.contract_id else None
    if not s or s.user_id!=access.user_id:raise HTTPException(404,'Your collection job was not found')
    audit(db,access.user_id,'consumer.missed_pickup_report',j.id,lga_id=s.lga_id,company_id=s.company_id,details={'reason':data.reason});commit(db)
    return {'status':'reported','message':'Your company and government staff can review this report.'}

@router.post('/companies/{company_id}/routes',status_code=201)
def create_route(company_id:str,data:RouteInput,access=Depends(get_access),db:Session=Depends(get_db)):
    company_scope(company_id,access,True);validate_area(db,company_id,data.lga_id)
    m=db.query(CompanyDriver).filter_by(id=data.driver_id,company_id=company_id,active=True).first()
    if not m:raise HTTPException(404,'Active company driver not found')
    c=db.get(Contractor,m.contractor_id);ensure_driver(c,c.user_id,db)
    v=db.query(Vehicle).filter_by(company_id=company_id,driver_id=m.id,active=True).first()
    if not v:raise HTTPException(409,'Driver needs an active company vehicle')
    if c.lga_id!=data.lga_id:raise HTTPException(422,'Driver LGA does not match route')
    if len({s.bin_id for s in data.stops})!=len(data.stops):raise HTTPException(422,'Each bin may occur once per route')
    for stop in data.stops:
        b=db.get(SmartBin,stop.bin_id)
        if not b or b.lga_id!=data.lga_id:raise HTTPException(422,'Route bin is outside the LGA')
        contract=db.get(ServiceContract,stop.contract_id) if stop.contract_id else None
        if stop.contract_id and (not contract or not contract.active or contract.company_id!=company_id or contract.lga_id!=data.lga_id or contract.bin_id!=stop.bin_id):raise HTTPException(403,'Service contract is outside this company, bin or area')
        if stop.invoice_id:
            link=db.get(ServiceInvoice,stop.invoice_id)
            if not contract or not link or link.contract_id!=contract.id:raise HTTPException(403,'Invoice does not belong to this service contract')
        if stop.pickup_id:
            link=db.get(PickupContract,stop.pickup_id);pickup=db.get(Pickup,stop.pickup_id)
            if not contract or not link or link.contract_id!=contract.id:raise HTTPException(403,'Pickup does not belong to this service contract')
            if pickup.status!='requested':raise HTTPException(409,'Pickup is already assigned or closed')
    route=CollectionRoute(contractor_id=c.id,lga_id=data.lga_id,bin_ids=','.join(s.bin_id for s in data.stops),notes=data.notes)
    db.add(route);db.flush();db.add(RouteAssignment(route_id=route.id,company_id=company_id,vehicle_id=v.id))
    for stop in data.stops:
        db.add(CollectionJob(route_id=route.id,company_id=company_id,**stop.model_dump()))
        if stop.pickup_id:db.get(Pickup,stop.pickup_id).status='assigned'
    audit(db,access.user_id,'route.assigned',route.id,company_id=company_id,lga_id=data.lga_id,details={'driver_id':m.id,'vehicle_id':v.id});commit(db)
    return {'id':route.id,'status':route.status.value}
@router.patch('/companies/{company_id}/routes/{route_id}/driver')
def reassign_route(company_id:str,route_id:str,data:ReassignInput,access=Depends(get_access),db:Session=Depends(get_db)):
    company_scope(company_id,access,True)
    assignment=db.query(RouteAssignment).filter_by(route_id=route_id,company_id=company_id).first()
    route=db.query(CollectionRoute).filter_by(id=route_id).with_for_update().first()
    if not assignment or not route:raise HTTPException(404,'Company route not found')
    if route.status not in (RouteStatus.ASSIGNED,RouteStatus.ACTIVE) or db.query(CollectionEvent).filter_by(route_id=route_id).first():raise HTTPException(409,'Route is closed or partly verified; create a new route for remaining bins')
    m=db.query(CompanyDriver).filter_by(id=data.driver_id,company_id=company_id,active=True).first()
    if not m:raise HTTPException(404,'Active company driver not found')
    c=db.get(Contractor,m.contractor_id);ensure_driver(c,c.user_id,db)
    v=db.query(Vehicle).filter_by(driver_id=m.id,company_id=company_id,active=True).first()
    if not v or c.lga_id!=route.lga_id:raise HTTPException(422,'Driver requires an active vehicle in this LGA')
    previous=route.contractor_id;route.contractor_id=c.id;assignment.vehicle_id=v.id;route.status=RouteStatus.ASSIGNED
    for j in db.query(CollectionJob).filter_by(route_id=route_id):
        j.status='assigned';j.missed_reason=None
        if j.pickup_id:db.get(Pickup,j.pickup_id).status='assigned'
    audit(db,access.user_id,'route.reassigned',route.id,company_id=company_id,lga_id=route.lga_id,details={'from_contractor_id':previous,'to_contractor_id':c.id});commit(db)
    return {'status':'assigned','driver_id':m.id}
@router.patch('/driver/jobs/{job_id}')
def update_job(job_id:str,data:JobStatusInput,access=Depends(get_access),db:Session=Depends(get_db)):
    j=db.query(CollectionJob).filter_by(id=job_id).with_for_update().first()
    if not j:raise HTTPException(404,'Job not found')
    route=db.get(CollectionRoute,j.route_id);c=db.get(Contractor,route.contractor_id);ensure_driver(c,access.user_id,db)
    if route.status not in (RouteStatus.ASSIGNED,RouteStatus.ACTIVE) or j.status in ('collected_verified','cancelled'):raise HTTPException(409,'Collection job is closed')
    if j.status=='missed':raise HTTPException(409,'A dispatcher must reassign a missed pickup')
    if data.status=='missed' and len(data.reason.strip())<5:raise HTTPException(422,'Provide a missed pickup reason')
    if data.status=='en_route' and j.status!='assigned':raise HTTPException(409,'Invalid job status transition')
    if data.status=='evidence_submitted' and j.status not in ('assigned','en_route'):raise HTTPException(409,'Invalid job status transition')
    j.status=data.status;j.missed_reason=data.reason if data.status=='missed' else None
    if j.pickup_id:db.get(Pickup,j.pickup_id).status=j.status
    audit(db,access.user_id,'collection.'+j.status,j.id,lga_id=route.lga_id,company_id=j.company_id,details={'reason':data.reason});commit(db)
    return job_out(db,j,False)
@router.get('/companies/{company_id}/audit')
def company_audit(company_id:str,access=Depends(get_access),db:Session=Depends(get_db)):
    _,areas=company_scope(company_id,access)
    rows=db.query(AuditEvent).filter(AuditEvent.company_id==company_id).order_by(AuditEvent.created_at.desc()).limit(200).all()
    return [{'id':r.id,'action':r.action,'resource_id':r.resource_id,'details':r.details,'created_at':str(r.created_at)} for r in rows if r.lga_id is None or r.lga_id in areas]

@router.get('/companies/{company_id}/bins')
def company_bins(company_id:str,lga_id:str,access=Depends(get_access),db:Session=Depends(get_db)):
    _,areas=company_scope(company_id,access)
    if lga_id not in areas:raise HTTPException(403,'Outside your company or government area')
    from app.routers.operations import bin_details
    return [bin_details(b) for b in db.query(SmartBin).filter_by(lga_id=lga_id).order_by(SmartBin.bin_code)]

@router.get('/contractor-directory')
def contractor_directory(state:str|None=None,lga_id:str|None=None,user=Depends(get_current_user),db:Session=Depends(get_db)):
    """Public company identifiers and approved areas for authenticated customers."""
    rows=[]
    for company in db.query(Company).filter_by(active=True).order_by(Company.name):
        areas=db.query(LGA).join(CompanyArea,CompanyArea.lga_id==LGA.id).filter(CompanyArea.company_id==company.id)
        if state:areas=areas.filter(LGA.state==state)
        if lga_id:areas=areas.filter(LGA.id==lga_id)
        places=areas.all()
        if places:rows.append({'id':company.id,'name':company.name,'areas':[{'lga_id':l.id,'lga':l.name,'state':l.state} for l in places]})
    return rows

class BankInput(Input):
    state:str=Field(min_length=2,max_length=100)
    bank_code:str=Field(pattern=r'^\d{3,6}$')
    account_number:str=Field(pattern=r'^\d{10}$')

class SelectionInput(Input):
    company_id:str

@router.get('/contractor-selection')
def selection(user=Depends(get_current_user),db:Session=Depends(get_db)):
    from app.models.access import CustomerContractor
    row=db.get(CustomerContractor,user.id)
    c=db.get(Company,row.company_id) if row else None
    return {'company_id':c.id if c and c.active else None}

@router.put('/contractor-selection')
def select_contractor(data:SelectionInput,user=Depends(get_current_user),db:Session=Depends(get_db)):
    from app.models.access import CustomerContractor
    c=db.get(Company,data.company_id)
    if not c or not c.active:raise HTTPException(404,'Approved contractor not found')
    row=db.get(CustomerContractor,user.id)
    if not row:row=CustomerContractor(user_id=user.id,company_id=c.id);db.add(row)
    else:row.company_id=c.id
    audit(db,user.id,'consumer.contractor_selected',c.id,company_id=c.id);commit(db)
    return {'company_id':c.id,'name':c.name}

@router.get('/companies/{company_id}/bank-profile')
def bank_profile(company_id:str,access=Depends(get_access),db:Session=Depends(get_db)):
    company_scope(company_id,access,True)
    from app.models.access import CompanyBank
    row=db.get(CompanyBank,company_id)
    if not row:return {'configured':False}
    return {'configured':True,'state':row.state,'bank_name':row.bank_name,'account_name':row.account_name,
        'account_number':'******'+row.account_number[-4:],'verified':row.verified}

@router.put('/companies/{company_id}/bank-profile')
def setup_bank(company_id:str,data:BankInput,access=Depends(get_access),db:Session=Depends(get_db)):
    company,areas=company_scope(company_id,access,True)
    if not any(db.get(LGA,l).state==data.state for l in areas):raise HTTPException(422,'State must match an approved service area')
    from app.models.access import CompanyBank
    from app.routers.paystack import provider
    banks=provider('/bank?country=nigeria&perPage=100')
    bank=next((b for b in banks if b['code']==data.bank_code),None)
    if not bank:raise HTTPException(422,'Choose a supported bank')
    resolved=provider('/bank/resolve?account_number='+data.account_number+'&bank_code='+data.bank_code)
    if resolved.get('account_number')!=data.account_number:raise HTTPException(502,'Account verification mismatch')
    result=provider('/subaccount',{'business_name':company.name,'settlement_bank':data.bank_code,
        'account_number':data.account_number,'percentage_charge':0,'description':'WastePay '+company.id})
    code=result.get('subaccount_code')
    if not code or not code.startswith('ACCT_'):raise HTTPException(502,'Contractor settlement setup failed')
    row=db.get(CompanyBank,company_id)
    if not row:row=CompanyBank(company_id=company_id);db.add(row)
    row.state=data.state;row.bank_code=data.bank_code;row.bank_name=bank['name'];row.account_number=data.account_number
    row.account_name=resolved['account_name'];row.subaccount_code=code;row.verified=True
    audit(db,access.user_id,'company.bank_verified',company_id,company_id=company_id,details={'bank':bank['name'],'last_four':data.account_number[-4:]});commit(db)
    return {'configured':True,'verified':True,'account_name':row.account_name,'bank_name':row.bank_name}
