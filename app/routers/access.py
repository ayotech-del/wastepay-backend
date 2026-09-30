from typing import Literal
from fastapi import APIRouter,Depends,HTTPException
from pydantic import BaseModel,Field,ConfigDict
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.permissions import require_platform,StaffGrant,legacy_grant,ROLE_PERMISSIONS,audit
from app.models.access import RoleGrant,Company
from app.models.models import User,LGA
router=APIRouter()
class GrantInput(BaseModel):
    user_id:str
    role:Literal['platform_admin','lga_admin','government_supervisor','government_operations','government_finance','contractor_manager']
    scope_kind:Literal['national','state','lga','company']
    scope_value:str|None=None
class ActiveInput(BaseModel):
    active:bool

def grant_out(g):
    return {'id':g.id,'user_id':g.user_id,'role':g.role,'scope_kind':g.scope_kind,'scope_value':g.scope_value,'active':g.active,
        'permissions':sorted(ROLE_PERMISSIONS.get(g.role,set()))}
@router.get('/grants')
def grants(access=Depends(require_platform),db:Session=Depends(get_db)):
    rows=db.query(RoleGrant).all();out=[grant_out(g) for g in rows]
    for s in db.query(StaffGrant):
        if not any(g.id=='legacy:'+s.user_id for g in rows):out.append(grant_out(legacy_grant(s)))
    return out
@router.post('/grants',status_code=201)
def assign_grant(data:GrantInput,access=Depends(require_platform),db:Session=Depends(get_db)):
    if not db.get(User,data.user_id):raise HTTPException(404,'Registered user not found')
    if data.role=='platform_admin' and (data.scope_kind!='national' or data.scope_value):raise HTTPException(422,'Platform access requires national scope')
    if data.role=='lga_admin' and data.scope_kind!='lga':raise HTTPException(422,'LGA administrators require LGA scope')
    if data.role=='contractor_manager' and data.scope_kind!='company':raise HTTPException(422,'Company managers require company scope')
    if data.role!='contractor_manager' and data.scope_kind=='company':raise HTTPException(422,'Government roles require a government area')
    if data.scope_kind=='national' and data.scope_value:raise HTTPException(422,'National scope has no scope value')
    if data.scope_kind=='lga' and not db.get(LGA,data.scope_value):raise HTTPException(404,'LGA not found')
    if data.scope_kind=='state' and not db.query(LGA).filter_by(state=data.scope_value).first():raise HTTPException(404,'State has no registered LGAs')
    if data.scope_kind=='company' and not db.get(Company,data.scope_value):raise HTTPException(404,'Company not found')
    grant=db.query(RoleGrant).filter_by(user_id=data.user_id,role=data.role,scope_kind=data.scope_kind,scope_value=data.scope_value).first()
    if grant:grant.active=True
    else:grant=RoleGrant(**data.model_dump());db.add(grant)
    db.flush();audit(db,access.user_id,'role.granted',grant.id,details=data.model_dump());db.commit()
    return grant_out(grant)
@router.patch('/grants/{grant_id}')
def change_grant(grant_id:str,data:ActiveInput,access=Depends(require_platform),db:Session=Depends(get_db)):
    grant=db.get(RoleGrant,grant_id)
    if not grant and grant_id.startswith('legacy:'):
        staff=db.get(StaffGrant,grant_id[7:])
        if staff:grant=legacy_grant(staff);db.add(grant)
    if not grant:raise HTTPException(404,'Role grant not found')
    if grant.role=='platform_admin' and not data.active:
        rows=db.query(RoleGrant).all()
        admins={g.user_id for g in rows if g.active and g.role=='platform_admin' and g.id!=grant.id}
        for staff in db.query(StaffGrant).filter_by(role='platform_admin'):
            if not any(g.id=='legacy:'+staff.user_id for g in rows) and 'legacy:'+staff.user_id!=grant.id:admins.add(staff.user_id)
        if not admins:raise HTTPException(409,'Provision another platform administrator before revoking the last one')
    grant.active=data.active;audit(db,access.user_id,'role.activated' if data.active else 'role.revoked',grant.id,
        details={'user_id':grant.user_id,'role':grant.role})
    db.commit();return grant_out(grant)
