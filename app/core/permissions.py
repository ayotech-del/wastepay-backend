"""Permissions are resolved from current database records on every request."""
import json
from dataclasses import dataclass
from fastapi import Depends, HTTPException
from sqlalchemy import Column, String, ForeignKey
from sqlalchemy.orm import Session
from app.core.database import Base, get_db
from app.routers.auth import get_current_user
from app.models.models import LGA
from app.models.access import RoleGrant, Company, CompanyArea, CompanyDriver, Vehicle, AuditEvent

class StaffGrant(Base):
    __tablename__ = 'staff_grants'
    user_id = Column(String, ForeignKey('users.id'), primary_key=True)
    role = Column(String, nullable=False)
    lga_id = Column(String, ForeignKey('lgas.id'), nullable=True)

ROLE_PERMISSIONS = {
    'platform_admin': {'government.view','government.operations','government.finance','access.manage'},
    'lga_admin': {'government.view','government.operations','government.finance'},
    'government_supervisor': {'government.view'},
    'government_operations': {'government.view','government.operations'},
    'government_finance': {'government.view','government.finance'},
    'contractor_manager': {'company.view','company.manage'},
    'driver': {'driver.work'},
}

def legacy_grant(staff):
    return RoleGrant(id='legacy:'+staff.user_id,user_id=staff.user_id,role=staff.role,
        scope_kind='national' if staff.role=='platform_admin' else 'lga',
        scope_value=None if staff.role=='platform_admin' else staff.lga_id,active=True)

@dataclass
class Access:
    user_id: str
    grants: list
    db: Session
    @property
    def role(self):
        return 'platform_admin' if any(g.role=='platform_admin' for g in self.grants) else (self.grants[0].role if self.grants else 'citizen')
    @property
    def lga_id(self):
        values={g.scope_value for g in self.grants if g.scope_kind=='lga'}
        return next(iter(values)) if len(values)==1 else None

def get_access(user=Depends(get_current_user),db:Session=Depends(get_db)):
    rows=db.query(RoleGrant).filter_by(user_id=user.id).all()
    grants=[]
    for g in rows:
        if not g.active:continue
        if g.scope_kind=='company':
            company=db.get(Company,g.scope_value)
            if not company or not company.active:continue
        grants.append(g)
    staff=db.get(StaffGrant,user.id)
    if staff and not any(g.id=='legacy:'+user.id for g in rows):grants.append(legacy_grant(staff))
    return Access(user.id,grants,db)

def require_permission(permission):
    def dependency(access=Depends(get_access)):
        grants=[g for g in access.grants if permission in ROLE_PERMISSIONS.get(g.role,set())]
        if not grants:raise HTTPException(403,'Required permission: '+permission)
        return Access(access.user_id,grants,access.db)
    return dependency

require_admin=require_permission('government.view')
require_operations=require_permission('government.operations')
require_finance=require_permission('government.finance')
require_platform=require_permission('access.manage')

def allowed_lgas(access,db):
    if not isinstance(access,Access):
        return [l.id for l in db.query(LGA).all()] if access.role=='platform_admin' else [access.lga_id]
    out=set()
    for g in access.grants:
        if g.scope_kind=='national':out.update(l.id for l in db.query(LGA).all())
        elif g.scope_kind=='lga' and g.scope_value:out.add(g.scope_value)
        elif g.scope_kind=='state':out.update(l.id for l in db.query(LGA).filter_by(state=g.scope_value))
    return sorted(out)

def check_lga(access,lga_id):
    if isinstance(access,Access):
        if lga_id not in allowed_lgas(access,access.db):raise HTTPException(403,'Outside your assigned government area')
    elif access.role!='platform_admin' and access.lga_id!=lga_id:raise HTTPException(403,'Outside your assigned LGA')

def company_access(company_id,access,permission='company.view'):
    company=access.db.get(Company,company_id)
    if not company or not company.active:raise HTTPException(404,'Active company not found')
    if not any(g.scope_kind=='company' and g.scope_value==company_id and permission in ROLE_PERMISSIONS.get(g.role,set()) for g in access.grants):
        raise HTTPException(403,'Outside your company access')
    return company

def ensure_driver(contractor,user_id,db):
    if not contractor or contractor.user_id!=user_id:raise HTTPException(403,'Driver account or route does not belong to you')
    if contractor.status.value=='suspended':raise HTTPException(403,'Driver is suspended')
    membership=db.query(CompanyDriver).filter_by(contractor_id=contractor.id).first()
    if membership:
        company=db.get(Company,membership.company_id)
        grant=db.query(RoleGrant).filter_by(user_id=user_id,role='driver',scope_kind='company',scope_value=membership.company_id,active=True).first()
        vehicle=db.query(Vehicle).filter_by(driver_id=membership.id,company_id=membership.company_id,active=True).first()
        if not membership.active or not company or not company.active or not grant or not vehicle:raise HTTPException(403,'Driver company access or vehicle is inactive')
    return membership

def audit(db,actor_id,action,resource_id,*,lga_id=None,company_id=None,details=None):
    db.add(AuditEvent(actor_id=actor_id,action=action,resource_id=resource_id,lga_id=lga_id,
        company_id=company_id,details=json.dumps(details or {})))

def describe_access(access,user):
    permissions=set()
    for g in access.grants:permissions.update(ROLE_PERMISSIONS.get(g.role,set())-{'driver.work'})
    if user.is_collector:
        from app.routers.contractors import Contractor
        c=access.db.query(Contractor).filter_by(user_id=user.id).first()
        try:
            ensure_driver(c,user.id,access.db);permissions.add('driver.work')
        except HTTPException:pass
    roles=[g.role for g in access.grants]
    primary='citizen'
    for role in ['platform_admin','lga_admin','government_operations','government_finance','government_supervisor','contractor_manager','driver']:
        if role in roles:primary=role;break
    if primary=='citizen' and 'driver.work' in permissions:primary='contractor'
    return {'role':primary,'roles':roles or [primary],'permissions':sorted(permissions),
        'grants':[{'id':g.id,'role':g.role,'scope_kind':g.scope_kind,'scope_value':g.scope_value,'permissions':sorted(ROLE_PERMISSIONS.get(g.role,set()))} for g in access.grants],
        'company_ids':sorted({g.scope_value for g in access.grants if g.scope_kind=='company'}),
        'permission_lga_ids':{p:allowed_lgas(Access(access.user_id,[g for g in access.grants if p in ROLE_PERMISSIONS.get(g.role,set())],access.db),access.db) for p in ['government.view','government.operations','government.finance']}}
