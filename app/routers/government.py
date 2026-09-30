import csv,io
from fastapi import APIRouter,Depends,HTTPException
from fastapi.responses import Response
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.permissions import require_admin,check_lga,allowed_lgas,require_platform,audit
from app.models.models import LGA,SmartBin,Transaction,User
from app.routers.billing import billing_stats
from app.routers.contractors import contractor_report,live_contractors
router=APIRouter()
@router.get('/my-lgas')
def my_lgas(grant=Depends(require_admin),db:Session=Depends(get_db)):
    q=db.query(LGA)
    q=q.filter(LGA.id.in_(allowed_lgas(grant,db)))
    return {'lgas':[{'id':l.id,'name':l.name,'state':l.state} for l in q.order_by(LGA.name).all()]}

from pydantic import BaseModel,Field,ConfigDict
from sqlalchemy.exc import IntegrityError
class LGAInput(BaseModel):
    model_config=ConfigDict(str_strip_whitespace=True)
    name:str=Field(min_length=2,max_length=200)
    state:str=Field(min_length=2,max_length=100)
@router.post('/lgas',status_code=201)
def create_lga(data:LGAInput,grant=Depends(require_platform),db:Session=Depends(get_db)):
    lga=LGA(**data.model_dump());db.add(lga)
    try:
        db.flush();audit(db,grant.user_id,'lga.created',lga.id,lga_id=lga.id);db.commit()
    except IntegrityError:
        db.rollback();raise HTTPException(409,'LGA already registered')
    db.refresh(lga)
    return {'id':lga.id,'name':lga.name,'state':lga.state}
@router.get('/dashboard/{lga_id}')
def dashboard(lga_id:str,grant=Depends(require_admin),db:Session=Depends(get_db)):
    check_lga(grant,lga_id)
    if not db.get(LGA,lga_id): raise HTTPException(404,'LGA not found')
    bins=db.query(SmartBin).filter_by(lga_id=lga_id).all()
    return {'billing':billing_stats(lga_id,grant,db),'performance':contractor_report(lga_id,grant,db),
        'live':live_contractors(lga_id,grant,db),'bins':len(bins),
        'alerts':[{'id':b.id,'bin_code':b.bin_code,'address':b.address,'fill_percent':b.fill_percent} for b in bins if b.fill_percent>=75]}
@router.get('/transactions/{lga_id}.csv')
def report(lga_id:str,grant=Depends(require_admin),db:Session=Depends(get_db)):
    check_lga(grant,lga_id)
    output=io.StringIO();writer=csv.writer(output)
    writer.writerow(['reference','type','amount_ngn','status','created_at'])
    for t in db.query(Transaction).join(User,Transaction.user_id==User.id).filter(User.lga_id==lga_id).yield_per(500):
        row=[t.reference,t.type.value,f'{t.amount:.2f}',t.status,str(t.created_at)]
        writer.writerow(["'"+str(v) if str(v).startswith(('=','+','-','@')) else v for v in row])
    return Response(output.getvalue(),media_type='text/csv',headers={'Content-Disposition':'attachment; filename="transactions.csv"'})
# Public directory contains no household or contractor personal data.
@router.get('/lgas')
def lgas(state:str|None=None,db:Session=Depends(get_db)):
    q=db.query(LGA)
    if state:q=q.filter_by(state=state)
    return {'lgas':[{'id':l.id,'name':l.name,'state':l.state} for l in q.order_by(LGA.name).all()]}
