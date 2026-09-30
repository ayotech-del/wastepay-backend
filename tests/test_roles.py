import pytest
from test_api import env,headers,TEST_PASSWORD
from app.core.core import hash_password,settings
from app.models.models import User,Wallet,LGA,SmartBin
from app.models.access import RoleGrant,Company,AuditEvent,CollectionJob
from app.routers.contractors import Contractor
HASH=hash_password(TEST_PASSWORD)

@pytest.fixture
def org(env):
    c,db=env
    db.add(LGA(id='outside',name='Outside LGA',state='Ogun'))
    for index,uid in enumerate(['root','managerA','managerB','driverA','driverB','driver2','ops','finance','supervisor','mixed']):
        db.add(User(id=uid,phone='+23481'+f'{index:08d}',full_name=uid,hashed_password=HASH))
        db.add(Wallet(user_id=uid,eco_credits=100))
    db.add(SmartBin(id='binB',bin_code='QRB',latitude=6.4,longitude=3.4,address='Second bin',lga_id='lga'))
    for uid,role,kind,value in [('root','platform_admin','national',None),('ops','government_operations','lga','lga'),
        ('finance','government_finance','lga','lga'),('supervisor','government_supervisor','state','Lagos'),
        ('mixed','government_operations','lga','lga'),('mixed','government_finance','lga','outside')]:
        db.add(RoleGrant(user_id=uid,role=role,scope_kind=kind,scope_value=value))
    db.commit()
    out={'client':c,'db':db}
    for suffix,user,bin_id,code in [('A','citizen','bin','QR1'),('B','other','binB','QRB')]:
        response=c.post('/organizations/companies',json={'name':'Company '+suffix,'lga_ids':['lga'],'manager_user_id':'manager'+suffix},headers=headers('ops'))
        assert response.status_code==201,response.text
        company=response.json()['id']
        response=c.post(f'/organizations/companies/{company}/vehicles',json={'truck_number':'TRUCK'+suffix},headers=headers('manager'+suffix))
        assert response.status_code==201,response.text
        vehicle=response.json()['id']
        response=c.post(f'/organizations/companies/{company}/drivers',json={'user_id':'driver'+suffix,'vehicle_id':vehicle,'lga_id':'lga'},headers=headers('manager'+suffix))
        assert response.status_code==201,response.text
        driver=response.json()['id'];contractor=response.json()['contractor_id']
        response=c.post('/organizations/contracts',json={'company_id':company,'user_id':user,'lga_id':'lga','household_ref':'HOUSE'+suffix,'address':'12 Test Street','bin_id':bin_id},headers=headers('ops'))
        assert response.status_code==201,response.text
        contract=response.json()['id']
        response=c.post('/billing/invoice/generate',json={'lga_id':'lga','contract_id':contract,'amount':80,'billing_period':'2026-09'},headers=headers('finance'))
        assert response.status_code==201,response.text
        invoice=response.json()['invoice']['id']
        response=c.post(f'/organizations/companies/{company}/routes',json={'driver_id':driver,'lga_id':'lga','stops':[{'bin_id':bin_id,'contract_id':contract,'invoice_id':invoice}]},headers=headers('manager'+suffix))
        assert response.status_code==201,response.text
        route=response.json()['id']
        job=c.get(f'/organizations/companies/{company}/dashboard',headers=headers('manager'+suffix)).json()['jobs'][0]['id']
        out[suffix]={'company':company,'driver':driver,'vehicle':vehicle,'contractor':contractor,'contract':contract,'invoice':invoice,'route':route,'job':job,'user':user,'bin':bin_id,'code':code}
    return out

def test_company_isolation_and_role_escalation(org):
    c=org['client'];a=org['A'];b=org['B']
    assert c.get(f"/organizations/companies/{b['company']}/dashboard",headers=headers('managerA')).status_code==403
    assert c.get(f"/organizations/companies/{b['company']}/audit",headers=headers('managerA')).status_code==403
    assert c.post(f"/organizations/companies/{b['company']}/vehicles",json={'truck_number':'UNAUTHORIZED'},headers=headers('managerA')).status_code==403
    assert c.get('/access/grants',headers=headers('managerA')).status_code==403
    assert c.post('/access/grants',json={'user_id':'managerA','role':'platform_admin','scope_kind':'national'},headers=headers('managerA')).status_code==403
    assert [row['id'] for row in c.get('/organizations/companies',headers=headers('managerA')).json()]==[a['company']]
    data=c.get(f"/organizations/companies/{a['company']}/dashboard",headers=headers('managerA')).json()
    assert data['invoices'][0]['id']==a['invoice'] and len(data['invoices'])==1
    assert 'bank_code' not in data['drivers'][0] and 'account_number' not in data['drivers'][0]
    assert c.get('/wallet/balance',headers=headers('managerA')).json()['eco_credits']==100

def test_government_scope_and_separation_of_duties(org):
    c=org['client'];a=org['A']
    assert [l['id'] for l in c.get('/government/my-lgas',headers=headers('supervisor')).json()['lgas']]==['lga']
    assert c.get('/government/dashboard/lga',headers=headers('supervisor')).status_code==200
    assert c.get('/government/dashboard/outside',headers=headers('supervisor')).status_code==403
    assert c.get('/contractors/live',params={'lga_id':'outside'},headers=headers('supervisor')).status_code==403
    assert c.post('/organizations/companies',json={'name':'Forbidden','lga_ids':['lga'],'manager_user_id':'managerA'},headers=headers('supervisor')).status_code==403
    assert c.post('/organizations/companies',json={'name':'Wrong area','lga_ids':['outside'],'manager_user_id':'managerA'},headers=headers('ops')).status_code==403
    body={'bin_code':'OPS-NEW','address':'12 Test Road','latitude':6.4,'longitude':3.4,'lga_id':'lga'}
    assert c.post('/bins',json=body,headers=headers('finance')).status_code==403
    assert c.post('/bins',json=body,headers=headers('supervisor')).status_code==403
    assert c.post('/bins',json=body,headers=headers('ops')).status_code==201
    invoice={'lga_id':'lga','contract_id':a['contract'],'amount':80,'billing_period':'2026-09'}
    assert c.post('/billing/invoice/generate',json=invoice,headers=headers('ops')).status_code==403
    assert c.post('/billing/invoice/generate',json=invoice,headers=headers('supervisor')).status_code==403
    assert c.post('/billing/invoice/generate',json=invoice,headers=headers('mixed')).status_code==403
    assert c.post('/contractors/payment/release',json={'route_id':a['route']},headers=headers('ops')).status_code==403
    assert c.post('/contractors/payment/release',json={'route_id':a['route']},headers=headers('finance')).status_code==409

def test_payment_and_verified_pickup_are_independent(org):
    c=org['client'];a=org['A']
    assert c.post(f"/billing/invoice/{a['invoice']}/pay",json={'payment_method':'eco_credits'},headers=headers('citizen')).status_code==200
    data=c.get(f"/organizations/companies/{a['company']}/dashboard",headers=headers('managerA')).json()
    assert data['jobs'][0]['payment_status']=='paid'
    assert data['jobs'][0]['collection_status']=='assigned'
    assert c.patch(f"/organizations/driver/jobs/{a['job']}",json={'status':'collected_verified'},headers=headers('driverA')).status_code==422
    for weight in (100,10):
        assert c.post('/bins/telemetry',json={'bin_code':a['code'],'weight_kg':weight,'fill_percent':10},headers={'x-telemetry-key':settings.TELEMETRY_KEY}).status_code==200
    body={'route_id':a['route'],'bin_id':a['bin'],'qr_scan_data':a['code'],'lat':6.4,'lng':3.4,'weight_kg':999}
    assert c.post('/contractors/collection/verify',json=body,headers=headers('driverB')).status_code==403
    assert c.post('/contractors/collection/verify',json=body,headers=headers('managerA')).status_code==403
    result=c.post('/contractors/collection/verify',json=body,headers=headers('driverA'))
    assert result.status_code==200,result.text
    data=c.get(f"/organizations/companies/{a['company']}/dashboard",headers=headers('managerA')).json()
    assert data['jobs'][0]['collection_status']=='collected_verified'
    assert data['jobs'][0]['payment_status']=='paid'
    assert data['routes'][0]['status']=='completed' and data['routes'][0]['payment_status']=='pending'
    result=c.post('/contractors/payment/release',json={'route_id':a['route']},headers=headers('finance'))
    assert result.status_code==200 and result.json()['status']=='awaiting_disbursement'
    assert c.post('/contractors/payment/release',json={'route_id':a['route']},headers=headers('finance')).status_code==409

def test_driver_isolation_revocation_and_gps(org):
    c=org['client'];a=org['A'];db=org['db']
    body={'contractor_id':a['contractor'],'lat':6.4,'lng':3.4,'status':'on_route'}
    assert c.post('/contractors/location/update',json=body,headers=headers('driverB')).status_code==403
    assert c.post('/contractors/location/update',json=body,headers=headers('driverA')).status_code==200
    driver=c.get(f"/organizations/companies/{a['company']}/dashboard",headers=headers('managerA')).json()['drivers'][0]
    assert driver['gps_stale'] is False and driver['position']['lat']==6.4
    assert c.patch(f"/organizations/driver/jobs/{a['job']}",json={'status':'en_route'},headers=headers('driverB')).status_code==403
    assert c.patch(f"/organizations/driver/jobs/{a['job']}",json={'status':'en_route'},headers=headers('driverA')).status_code==200
    result=c.patch(f"/organizations/companies/{a['company']}/drivers/{a['driver']}",json={'active':False},headers=headers('managerA'))
    assert result.status_code==200,result.text
    assert c.get('/contractors/my-routes',headers=headers('driverA')).status_code==403
    assert c.post('/contractors/location/update',json=body,headers=headers('driverA')).status_code==403
    assert 'driver.work' not in c.get('/users/me',headers=headers('driverA')).json()['permissions']
    grant=db.query(RoleGrant).filter_by(user_id='managerA',role='contractor_manager').one()
    assert c.patch(f'/access/grants/{grant.id}',json={'active':False},headers=headers('root')).status_code==200
    assert c.get(f"/organizations/companies/{a['company']}/dashboard",headers=headers('managerA')).status_code==403

def test_service_invoice_and_consumer_privacy(org):
    c=org['client'];a=org['A'];b=org['B']
    bad={'driver_id':a['driver'],'lga_id':'lga','stops':[{'bin_id':a['bin'],'contract_id':a['contract'],'invoice_id':b['invoice']}]}
    assert c.post(f"/organizations/companies/{a['company']}/routes",json=bad,headers=headers('managerA')).status_code==403
    assert [s['id'] for s in c.get('/organizations/contracts/mine',headers=headers('citizen')).json()]==[a['contract']]
    assert [s['id'] for s in c.get('/organizations/jobs/mine',headers=headers('citizen')).json()]==[a['job']]
    assert c.post(f"/organizations/jobs/{a['job']}/report",json={'reason':'Pickup was missed'},headers=headers('other')).status_code==404
    assert c.post(f"/organizations/jobs/{a['job']}/report",json={'reason':'Pickup was missed'},headers=headers('citizen')).status_code==201
    events=c.get(f"/organizations/companies/{a['company']}/audit",headers=headers('managerA')).json()
    assert any(e['action']=='consumer.missed_pickup_report' for e in events)
    assert c.post('/pickups',json={'address':'12 Other Street','contract_id':b['contract']},headers=headers('citizen')).status_code==403
    pickup=c.post('/pickups',json={'address':'12 Test Street','contract_id':a['contract']},headers=headers('citizen'))
    assert pickup.status_code==201,pickup.text
    assert len(c.get(f"/organizations/companies/{a['company']}/dashboard",headers=headers('managerA')).json()['pickup_requests'])==1
    assert c.get(f"/organizations/companies/{b['company']}/dashboard",headers=headers('managerB')).json()['pickup_requests']==[]

def test_missed_reason_reassignment_and_old_driver_block(org):
    c=org['client'];a=org['A']
    path=f"/organizations/driver/jobs/{a['job']}"
    assert c.patch(path,json={'status':'missed','reason':'x'},headers=headers('driverA')).status_code==422
    assert c.patch(path,json={'status':'missed','reason':'Road inaccessible'},headers=headers('driverA')).status_code==200
    assert c.patch(path,json={'status':'en_route'},headers=headers('driverA')).status_code==409
    v=c.post(f"/organizations/companies/{a['company']}/vehicles",json={'truck_number':'SECOND-TRUCK'},headers=headers('managerA')).json()['id']
    d=c.post(f"/organizations/companies/{a['company']}/drivers",json={'user_id':'driver2','vehicle_id':v,'lga_id':'lga'},headers=headers('managerA')).json()['id']
    result=c.patch(f"/organizations/companies/{a['company']}/routes/{a['route']}/driver",json={'driver_id':d},headers=headers('managerA'))
    assert result.status_code==200,result.text
    assert c.patch(path,json={'status':'en_route'},headers=headers('driverA')).status_code==403
    assert c.patch(path,json={'status':'en_route'},headers=headers('driver2')).status_code==200
    events=c.get(f"/organizations/companies/{a['company']}/audit",headers=headers('managerA')).json()
    assert any(e['action']=='collection.missed' and 'Road inaccessible' in e['details'] for e in events)
    assert any(e['action']=='route.reassigned' for e in events)

def test_current_role_grants_and_legacy_revocation(org):
    c=org['client']
    assert c.patch('/access/grants/legacy:admin',json={'active':False},headers=headers('root')).status_code==200
    assert c.get('/government/dashboard/lga',headers=headers('admin')).status_code==403
    response=c.post('/access/grants',json={'user_id':'other','role':'government_supervisor','scope_kind':'national'},headers=headers('root'))
    assert response.status_code==201,response.text
    assert c.get('/government/dashboard/outside',headers=headers('other')).status_code==200
    assert c.post('/bins',json={'bin_code':'INVALID','address':'12 Test Road','latitude':6.4,'longitude':3.4,'lga_id':'lga'},headers=headers('other')).status_code==403
    assert c.post('/access/grants',json={'user_id':'other','role':'platform_admin','scope_kind':'company','scope_value':org['A']['company']},headers=headers('root')).status_code==422

@pytest.mark.parametrize('resource',['vehicle','driver','invoice','company'])
def test_invalid_or_duplicate_business_registration(org,resource):
    c=org['client'];a=org['A']
    if resource=='vehicle':
        result=c.post(f"/organizations/companies/{a['company']}/vehicles",json={'truck_number':'TRUCKA'},headers=headers('managerA'))
        assert result.status_code==409
    elif resource=='driver':
        result=c.post(f"/organizations/companies/{a['company']}/drivers",json={'user_id':'driver2','vehicle_id':org['B']['vehicle'],'lga_id':'lga'},headers=headers('managerA'))
        assert result.status_code==404
    elif resource=='invoice':
        result=c.post('/billing/invoice/generate',json={'lga_id':'lga','contract_id':a['contract'],'user_id':'other','amount':1,'billing_period':'2026-09'},headers=headers('finance'))
        assert result.status_code==422
    else:
        org['db'].get(Company,a['company']).active=False;org['db'].commit()
        assert c.get(f"/organizations/companies/{a['company']}/dashboard",headers=headers('managerA')).status_code==403
        assert c.get('/contractors/my-routes',headers=headers('driverA')).status_code==403


def test_customer_directory_and_verified_contractor_checkout(org,monkeypatch):
    from app.models.access import CompanyBank
    from app.routers import paystack
    c=org['client'];a=org['A'];b=org['B'];calls=[]
    def fake(path,payload=None):
        calls.append((path,payload))
        if path.startswith('/bank?'):return [{'code':'058','name':'Test Bank'}]
        if path.startswith('/bank/resolve?'):return {'account_number':'0123456789','account_name':'Company A'}
        if path=='/subaccount':return {'subaccount_code':'ACCT_test_A'}
        return {'authorization_url':'https://checkout.paystack.com/test'}
    monkeypatch.setattr(paystack,'provider',fake)
    directory=c.get('/organizations/contractor-directory?state=Lagos',headers=headers('citizen'))
    assert directory.status_code==200 and len(directory.json())==2
    assert c.get('/organizations/contractor-directory?state=Ogun',headers=headers('citizen')).json()==[]
    payload={'state':'Lagos','bank_code':'058','account_number':'0123456789'}
    assert c.put(f"/organizations/companies/{b['company']}/bank-profile",json=payload,headers=headers('managerA')).status_code==403
    assert c.put(f"/organizations/companies/{a['company']}/bank-profile",json={**payload,'state':'Ogun'},headers=headers('managerA')).status_code==422
    c.put('/organizations/contractor-selection',json={'company_id':a['company']},headers=headers('citizen'))
    checkout={'purpose':'levy_payment','invoice_id':a['invoice'],'company_id':a['company'],'amount':80,'email':'test@example.com','channel':'card'}
    assert c.post('/paystack/initialize',json=checkout,headers=headers('citizen')).status_code==409
    assert c.put(f"/organizations/companies/{a['company']}/bank-profile",json=payload,headers=headers('managerA')).status_code==200
    profile=c.get(f"/organizations/companies/{a['company']}/bank-profile",headers=headers('managerA')).json()
    assert profile['account_number']=='******6789' and 'subaccount_code' not in profile
    result=c.post('/paystack/initialize',json=checkout,headers=headers('citizen'));assert result.status_code==200,result.text
    assert calls[-1][1]['subaccount']=='ACCT_test_A' and calls[-1][1]['channels']==['card']
    assert c.post('/paystack/initialize',json={**checkout,'invoice_id':b['invoice']},headers=headers('citizen')).status_code==403
    c.put('/organizations/contractor-selection',json={'company_id':b['company']},headers=headers('citizen'))
    assert c.post('/paystack/initialize',json=checkout,headers=headers('citizen')).status_code==403
    assert next(i for i in c.get('/billing/my-invoices',headers=headers('citizen')).json() if i['id']==a['invoice'])['contractor_name']=='Company A'
    assert org['db'].get(CompanyBank,a['company']).verified
