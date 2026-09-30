import hashlib,hmac,json
from datetime import datetime,timedelta
import pytest, secrets
TEST_PASSWORD = secrets.token_urlsafe(16)
TEST_PHONE = "+2348" + "".join(str(secrets.randbelow(10)) for _ in range(9))
TEST_LOCAL_PHONE = "0" + TEST_PHONE[4:]
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from app.main import app
from app.core.database import Base,get_db
from app.core.core import settings,create_access_token,hash_password
from app.models.models import User,Wallet,LGA,SmartBin
from app.core.permissions import StaffGrant
from app.routers.billing import Invoice,InvoiceStatus
from app.routers.paystack import PaymentIntent
from app.routers.contractors import Contractor,CollectionRoute
@pytest.fixture
def env():
    engine=create_engine('sqlite://',connect_args={'check_same_thread':False},poolclass=StaticPool)
    Base.metadata.create_all(engine); Session=sessionmaker(bind=engine)
    db=Session()
    db.add(LGA(id='lga',name='Test LGA',state='Lagos'))
    for index,uid in enumerate(('citizen','other','admin','driver')):
        db.add(User(id=uid,phone='+23480'+str(index)*8,full_name=uid,hashed_password=hash_password(TEST_PASSWORD)))
        db.add(Wallet(user_id=uid,eco_credits=100))
    db.add(StaffGrant(user_id='admin',role='lga_admin',lga_id='lga'))
    db.add(SmartBin(id='bin',bin_code='QR1',latitude=6.4,longitude=3.4,address='test bin',lga_id='lga'))
    db.add(Contractor(id='truck',user_id='driver',lga_id='lga',truck_number='TR1'))
    db.add(CollectionRoute(id='route',contractor_id='truck',lga_id='lga',bin_ids='bin'))
    db.add(Invoice(id='invoice',invoice_number='INV1',lga_id='lga',user_id='citizen',amount=80,
        billing_period='2026-09',due_date=datetime.utcnow()+timedelta(days=10),status=InvoiceStatus.SENT))
    db.commit()
    def dependency():
        s=Session()
        try: yield s
        except Exception: s.rollback();raise
        finally:s.close()
    app.dependency_overrides[get_db]=dependency
    settings.PAYSTACK_SECRET_KEY=secrets.token_hex(32);settings.TELEMETRY_KEY=secrets.token_hex(32)
    with TestClient(app) as client: yield client,db
    app.dependency_overrides.clear();db.close();engine.dispose()
def headers(uid='citizen'):return {'Authorization':'Bearer '+create_access_token({'sub':uid})}
def test_registration_login(env):
    c,_=env
    r=c.post('/auth/register',json={'phone':TEST_LOCAL_PHONE,'full_name':'Test','password':TEST_PASSWORD})
    assert r.status_code==201,r.text
    assert c.post('/auth/login',data={'username':TEST_PHONE,'password':TEST_PASSWORD}).status_code==200
    assert c.post('/auth/register',json={'phone':TEST_PHONE,'full_name':'Test','password':TEST_PASSWORD}).status_code==400
def test_billing_debits_and_owner(env):
    c,db=env
    assert c.post('/billing/invoice/invoice/pay',json={'payment_method':'eco_credits'},headers=headers('other')).status_code==403
    r=c.post('/billing/invoice/invoice/pay',json={'payment_method':'eco_credits'},headers=headers());assert r.status_code==200,r.text
    db.expire_all();assert db.query(Wallet).filter_by(user_id='citizen').one().eco_credits==20
    assert c.post('/billing/invoice/invoice/pay',json={'payment_method':'eco_credits'},headers=headers()).status_code==400
@pytest.mark.parametrize('amount',[-1,0,81])
def test_invalid_amount(env,amount):
    c,_=env
    assert c.post('/billing/invoice/invoice/pay',json={'payment_method':'eco_credits','amount':amount},headers=headers()).status_code==422
def test_permission_and_profile(env):
    c,_=env
    assert c.get('/users/me').status_code==401
    assert c.get('/users/me',headers=headers()).json()['role']=='citizen'
    assert c.get('/contractors/live',headers=headers()).status_code==403
    assert c.get('/billing/stats/another',headers=headers('admin')).status_code==403
    assert c.post('/wallet/redeem',json={'amount':10,'biller_code':'DSTV','customer_ref':'123'},headers=headers()).status_code==503
def test_pending_deposit_and_pickup(env):
    c,db=env
    r=c.post('/waste/deposit',json={'waste_type':'plastic','weight_kg':10,'bin_id':'bin'},headers=headers())
    assert r.status_code==200 and r.json()['credit_value']==0
    db.expire_all();assert db.query(Wallet).filter_by(user_id='citizen').one().eco_credits==100
    assert c.post('/pickups',json={'address':'10 Test Street'},headers=headers()).status_code==201
    assert len(c.get('/pickups',headers=headers()).json())==1
    assert c.get('/pickups',headers=headers('other')).json()==[]
def test_trusted_collection(env):
    c,_=env
    body={'route_id':'route','bin_id':'bin','weight_kg':999,'qr_scan_data':'QR1','lat':6.4,'lng':3.4}
    assert c.post('/contractors/collection/verify',json=body,headers=headers('other')).status_code==403
    assert c.post('/contractors/collection/verify',json=body,headers=headers('driver')).status_code==422
    assert c.post('/bins/telemetry',json={'bin_code':'QR1','weight_kg':100,'fill_percent':80}).status_code==401
    for kg,fill in [(100,80),(10,5)]:
        assert c.post('/bins/telemetry',json={'bin_code':'QR1','weight_kg':kg,'fill_percent':fill},headers={'x-telemetry-key':settings.TELEMETRY_KEY}).status_code==200
    assert c.post('/contractors/collection/verify',json={**body,'lat':0},headers=headers('driver')).status_code==422
    r=c.post('/contractors/collection/verify',json=body,headers=headers('driver'))
    assert r.status_code==200,r.text
    assert r.json()['weight_kg']==90
    assert c.post('/contractors/collection/verify',json=body,headers=headers('driver')).status_code==409
    r=c.post('/contractors/payment/release',json={'route_id':'route'},headers=headers('admin'))
    assert r.status_code==200 and r.json()['status']=='awaiting_disbursement'
    assert c.post('/contractors/payment/release',json={'route_id':'route'},headers=headers('admin')).status_code==409
def test_webhook_once_and_verify_once(env,monkeypatch):
    c,db=env
    db.add(PaymentIntent(reference='REF',user_id='citizen',amount_kobo=5000,purpose='wallet_topup'));db.commit()
    data={'reference':'REF','status':'success','amount':5000,'currency':'NGN'}
    raw=json.dumps({'event':'charge.success','data':data}).encode()
    sig=hmac.new(settings.PAYSTACK_SECRET_KEY.encode(),raw,hashlib.sha512).hexdigest()
    assert c.post('/paystack/webhook',content=raw).status_code==401
    for url in ('/paystack/webhook','/webhooks/paystack'):
        assert c.post(url,content=raw,headers={'x-paystack-signature':sig}).status_code==200
    monkeypatch.setattr('app.routers.paystack.provider',lambda *a:data)
    assert c.get('/paystack/verify/REF',headers=headers()).status_code==200
    db.expire_all();assert db.query(Wallet).filter_by(user_id='citizen').one().eco_credits==150
    assert c.get('/paystack/verify/REF',headers=headers('other')).status_code==404

def test_verified_recycling_credits_once(env):
    c,db=env
    r=c.post('/waste/deposit',json={'waste_type':'plastic','weight_kg':2,'bin_id':'bin','qr_scan_data':'QR1'},headers=headers())
    did=r.json()['deposit_id']
    for kg in (10,12):
        c.post('/bins/telemetry',json={'bin_code':'QR1','weight_kg':kg,'fill_percent':10},headers={'x-telemetry-key':settings.TELEMETRY_KEY})
    assert c.post(f'/waste/deposit/{did}/verify',headers=headers()).status_code==403
    r=c.post(f'/waste/deposit/{did}/verify',headers=headers('admin'))
    assert r.status_code==200,r.text
    assert r.json()['credit_value']==800
    assert c.post(f'/waste/deposit/{did}/verify',headers=headers('admin')).status_code==409
    db.expire_all();assert db.query(Wallet).filter_by(user_id='citizen').one().eco_credits==900

def test_government_and_no_fake_integrations(env):
    c,_=env
    assert c.get('/government/dashboard/lga',headers=headers()).status_code==403
    r=c.get('/government/dashboard/lga',headers=headers('admin'))
    assert r.status_code==200 and r.json()['billing']['total_billed']==80
    assert c.get('/government/transactions/other.csv',headers=headers('admin')).status_code==403
    assert c.post('/users/kyc/nin',headers=headers()).status_code==503
    assert c.post('/auth/login',data={'username':'bad','password':'bad'}).status_code==401

def test_mismatched_webhook_rolls_back(env):
    c,db=env
    db.add(PaymentIntent(reference='WRONG',user_id='citizen',amount_kobo=5000,purpose='wallet_topup'));db.commit()
    raw=json.dumps({'event':'charge.success','data':{'reference':'WRONG','status':'success','currency':'USD','amount':5000}}).encode()
    sig=hmac.new(settings.PAYSTACK_SECRET_KEY.encode(),raw,hashlib.sha512).hexdigest()
    assert c.post('/paystack/webhook',content=raw,headers={'x-paystack-signature':sig}).status_code==409
    db.expire_all();assert db.get(PaymentIntent,'WRONG').status=='pending'
    assert db.query(Wallet).filter_by(user_id='citizen').one().eco_credits==100
