"""Local operator provisioning; public registration never grants staff access."""
import argparse,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from app.main import app
from app.core.database import Base,engine,SessionLocal
from app.models.access import RoleGrant,Company
from app.models.models import User,LGA
from app.core.permissions import audit,StaffGrant,legacy_grant
p=argparse.ArgumentParser()
p.add_argument('--phone',required=True)
p.add_argument('--role',required=True,choices=['platform_admin','lga_admin','government_supervisor','government_operations','government_finance','contractor_manager'])
p.add_argument('--lga-id');p.add_argument('--state');p.add_argument('--national',action='store_true');p.add_argument('--company-id')
p.add_argument('--revoke',action='store_true');args=p.parse_args()
Base.metadata.create_all(engine)
with SessionLocal() as db:
    user=db.query(User).filter_by(phone=args.phone).first()
    if not user:sys.exit('Register this user first; use canonical +234 phone format')
    staff=db.get(StaffGrant,user.id)
    if staff and not db.get(RoleGrant,'legacy:'+user.id):db.add(legacy_grant(staff));db.flush()
    if args.role=='platform_admin':kind='national';value=None
    elif args.role=='contractor_manager':
        if not db.get(Company,args.company_id):sys.exit('A valid --company-id is required')
        kind='company';value=args.company_id
    elif args.lga_id:
        if not db.get(LGA,args.lga_id):sys.exit('A valid --lga-id is required')
        kind='lga';value=args.lga_id
    elif args.state and args.role!='lga_admin':
        if not db.query(LGA).filter_by(state=args.state).first():sys.exit('State has no registered LGAs')
        kind='state';value=args.state
    elif args.national and args.role!='lga_admin':kind='national';value=None
    else:sys.exit('Supply --lga-id, --state or --national for government scope')
    grant=db.query(RoleGrant).filter_by(user_id=user.id,role=args.role,scope_kind=kind,scope_value=value).first()
    if not grant:grant=RoleGrant(user_id=user.id,role=args.role,scope_kind=kind,scope_value=value);db.add(grant)
    grant.active=not args.revoke;db.flush()
    audit(db,user.id,'role.operator_provisioned',grant.id,details={'role':args.role,'scope_kind':kind,'scope_value':value,'active':grant.active})
    db.commit();print('Staff access updated:',grant.id)
