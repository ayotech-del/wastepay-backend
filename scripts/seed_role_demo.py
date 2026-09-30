"""Opt-in local SQLite role demo. Never seeds production or reusable passwords."""
import argparse,secrets,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from app.main import app
from app.core.database import Base,engine,SessionLocal
from app.core.core import settings,hash_password
from app.models.models import User,Wallet,LGA,SmartBin
from app.models.access import Company,CompanyArea,CompanyDriver,Vehicle,RoleGrant,ServiceContract,ServiceInvoice,RouteAssignment,CollectionJob
from app.routers.contractors import Contractor,CollectionRoute
from app.routers.billing import Invoice,InvoiceStatus
from datetime import datetime,timedelta
p=argparse.ArgumentParser();p.add_argument('--confirm-local',action='store_true');p.add_argument('--credentials-file',type=Path);args=p.parse_args()
if not args.confirm_local or settings.ENVIRONMENT=='production' or not settings.DATABASE_URL.startswith('sqlite:///'):
    sys.exit('Use --confirm-local with a development SQLite file only. No changes made.')
credential_file=args.credentials_file or Path(__file__).resolve().parents[1]/'ROLE_TEST_ACCOUNTS.md'
if credential_file.exists():sys.exit('Demo credentials already exist; existing accounts were not changed.')
Base.metadata.create_all(engine)
accounts=[('admin','Platform administrator','platform_admin'),('supervisor','Government supervisor','government_supervisor'),
    ('finance','Government finance','government_finance'),('operations','Government operations','government_operations'),
    ('manager-a','Company A manager','contractor_manager'),('manager-b','Company B manager','contractor_manager'),
    ('driver-a','Company A driver','driver'),('driver-b','Company B driver','driver'),
    ('consumer-a','Company A consumer','citizen'),('consumer-b','Company B consumer','citizen')]
rows=[]
with SessionLocal() as db:
    if db.get(User,'wp-demo-admin'):sys.exit('Demo users already exist; refusing to reset passwords.')
    lga=LGA(id='wp-demo-lga',name='WastePay Demo LGA',state='Lagos');db.add(lga)
    for key,label,role in accounts:
        phone='+2348'+''.join(str(secrets.randbelow(10)) for _ in range(9))
        while db.query(User).filter_by(phone=phone).first():phone='+2348'+''.join(str(secrets.randbelow(10)) for _ in range(9))
        password=secrets.token_urlsafe(18);uid='wp-demo-'+key
        db.add(User(id=uid,phone=phone,full_name='Demo '+label,hashed_password=hash_password(password),is_collector=role=='driver'))
        db.add(Wallet(user_id=uid,eco_credits=200 if role=='citizen' else 0))
        if role.startswith('government_') or role=='platform_admin':db.add(RoleGrant(user_id=uid,role=role,scope_kind='national'))
        rows.append((label,phone,password,uid))
    db.flush()
    for suffix in ('a','b'):
        company_id='wp-demo-company-'+suffix;bin_id='wp-demo-bin-'+suffix
        manager='wp-demo-manager-'+suffix;driver='wp-demo-driver-'+suffix;consumer='wp-demo-consumer-'+suffix
        db.add(Company(id=company_id,name='WastePay Demo Company '+suffix.upper()))
        db.add(CompanyArea(company_id=company_id,lga_id=lga.id))
        db.add(RoleGrant(user_id=manager,role='contractor_manager',scope_kind='company',scope_value=company_id))
        db.add(RoleGrant(user_id=driver,role='driver',scope_kind='company',scope_value=company_id))
        truck='DEMO-TRUCK-'+suffix.upper();cid='wp-demo-contractor-'+suffix;mid='wp-demo-membership-'+suffix;vid='wp-demo-vehicle-'+suffix
        db.add(Contractor(id=cid,user_id=driver,lga_id=lga.id,truck_number=truck))
        db.add(CompanyDriver(id=mid,company_id=company_id,contractor_id=cid))
        db.add(Vehicle(id=vid,company_id=company_id,truck_number=truck,driver_id=mid))
        db.add(SmartBin(id=bin_id,bin_code='WP-DEMO-'+suffix.upper(),address='Demo bin '+suffix.upper()+' (not a physical installation)',latitude=6.4550,longitude=3.3841,lga_id=lga.id))
        sid='wp-demo-service-'+suffix;iid='wp-demo-invoice-'+suffix;rid='wp-demo-route-'+suffix
        db.add(ServiceContract(id=sid,company_id=company_id,user_id=consumer,lga_id=lga.id,household_ref='DEMO-HOUSE-'+suffix.upper(),address='Demo service address '+suffix.upper(),bin_id=bin_id))
        db.add(Invoice(id=iid,invoice_number='WP-DEMO-INV-'+suffix.upper(),lga_id=lga.id,user_id=consumer,amount=80,
            billing_period=datetime.utcnow().strftime('%Y-%m'),due_date=datetime.utcnow()+timedelta(days=14),status=InvoiceStatus.SENT))
        db.add(ServiceInvoice(invoice_id=iid,contract_id=sid))
        db.add(CollectionRoute(id=rid,contractor_id=cid,lga_id=lga.id,bin_ids=bin_id))
        db.add(RouteAssignment(route_id=rid,company_id=company_id,vehicle_id=vid))
        db.add(CollectionJob(id='wp-demo-job-'+suffix,route_id=rid,company_id=company_id,bin_id=bin_id,contract_id=sid,invoice_id=iid))
    db.commit()
    content='# Local role test accounts\n\nDevelopment SQLite only. Demo credits are test data, not money. These bins are not physical installations.\n\n'
    content+='| Account | Phone | Password |\n| --- | --- | --- |\n'
    content+=''.join('| '+label+' | '+phone+' | '+password+' |\n' for label,phone,password,uid in rows)
    content+='\nOpen http://localhost:3000. Sign out between roles. Government accounts can view demo operations; each manager sees their own company; drivers see their own route; consumers can pay their own demo invoice using demo credits.\n'
    credential_file.write_text(content,encoding='utf-8')
print('Created local role demo. Credentials:',credential_file)
