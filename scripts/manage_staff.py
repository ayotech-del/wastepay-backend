"""Operator-only role provisioning. Run from backend directory."""
import argparse,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from app.main import app
from app.core.database import Base,engine,SessionLocal
from app.core.permissions import StaffGrant
from app.models.models import User,LGA
p=argparse.ArgumentParser()
p.add_argument('--phone',required=True);p.add_argument('--role',choices=['platform_admin','lga_admin'],required=True)
p.add_argument('--lga-id');args=p.parse_args()
Base.metadata.create_all(engine)
with SessionLocal() as db:
    user=db.query(User).filter_by(phone=args.phone).first()
    if not user:sys.exit('Register this user first; use canonical +234 phone format')
    if args.role=='lga_admin' and not db.get(LGA,args.lga_id):sys.exit('A valid --lga-id is required')
    grant=db.get(StaffGrant,user.id) or StaffGrant(user_id=user.id)
    grant.role=args.role;grant.lga_id=args.lga_id;db.add(grant);db.commit()
    print('Staff access updated')
