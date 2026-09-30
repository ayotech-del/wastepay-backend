import os,subprocess,sys
from pathlib import Path
from sqlalchemy import create_engine,text
from sqlalchemy.orm import Session
from app.core.database import Base
from app.core.permissions import StaffGrant
from app.models.models import User,LGA
from app.routers.contractors import Contractor,CollectionRoute,CollectionEvent

ROOT=Path(__file__).resolve().parents[1]
def run_upgrade(path):
    env=dict(os.environ,DATABASE_URL='sqlite:///'+path.as_posix(),ENVIRONMENT='development')
    return subprocess.run([sys.executable,str(ROOT/'scripts/upgrade_database.py')],cwd=ROOT,env=env,capture_output=True,text=True,timeout=30)

def test_migration_preserves_legacy_staff_and_revocation(tmp_path):
    path=tmp_path/'legacy.db';engine=create_engine('sqlite:///'+path.as_posix())
    Base.metadata.create_all(engine,tables=[User.__table__,LGA.__table__,StaffGrant.__table__,Contractor.__table__,CollectionRoute.__table__,CollectionEvent.__table__])
    with Session(engine) as db:
        db.add(LGA(id='legacy-lga',name='Legacy LGA',state='Lagos'))
        db.add(User(id='legacy-user',phone='+2348000000000',full_name='Preserved staff',hashed_password='existing-hash'))
        db.add(StaffGrant(user_id='legacy-user',role='lga_admin',lga_id='legacy-lga'));db.commit()
    result=run_upgrade(path);assert result.returncode==0,result.stderr
    with engine.begin() as conn:
        assert conn.execute(text("SELECT role,scope_kind,scope_value,active FROM role_grants WHERE id='legacy:legacy-user'")).one()==('lga_admin','lga','legacy-lga',1)
        assert conn.execute(text("SELECT hashed_password FROM users WHERE id='legacy-user'")).scalar()=='existing-hash'
        conn.execute(text("UPDATE role_grants SET active=0 WHERE id='legacy:legacy-user'"))
    result=run_upgrade(path);assert result.returncode==0,result.stderr
    with engine.connect() as conn:
        assert conn.execute(text('SELECT COUNT(*) FROM role_grants')).scalar()==1
        assert conn.execute(text("SELECT active FROM role_grants WHERE id='legacy:legacy-user'")).scalar()==0
    engine.dispose()

def test_migration_refuses_historical_duplicates_without_deleting(tmp_path):
    path=tmp_path/'duplicates.db';engine=create_engine('sqlite:///'+path.as_posix())
    with engine.begin() as conn:
        conn.execute(text('CREATE TABLE collection_events(id TEXT PRIMARY KEY,route_id TEXT,bin_id TEXT)'))
        conn.execute(text("INSERT INTO collection_events VALUES ('1','route','bin'),('2','route','bin')"))
    result=run_upgrade(path)
    assert result.returncode!=0
    assert 'Duplicate historical collections' in result.stderr
    with engine.connect() as conn:assert conn.execute(text('SELECT COUNT(*) FROM collection_events')).scalar()==2
    engine.dispose()
