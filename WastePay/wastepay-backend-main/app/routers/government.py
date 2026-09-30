import csv,io
from fastapi import APIRouter,Depends,HTTPException
from fastapi.responses import Response
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.permissions import require_admin,check_lga
from app.models.models import LGA,SmartBin,Transaction,User
from app.routers.billing import billing_stats
from app.routers.contractors import contractor_report,live_contractors
router=APIRouter()
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
