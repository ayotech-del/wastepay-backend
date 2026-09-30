"""Add tables and collection uniqueness without deleting historical data.
Back up your database first. Run during a maintenance window.
"""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from sqlalchemy import text
from app.main import app
from app.core.database import Base,engine
Base.metadata.create_all(engine)
with engine.begin() as conn:
    duplicates=conn.execute(text('SELECT route_id, bin_id, COUNT(*) FROM collection_events GROUP BY route_id, bin_id HAVING COUNT(*) > 1')).fetchall()
    if duplicates: raise SystemExit('Duplicate historical collections exist. Reconcile them before retrying; no records were deleted.')
    conn.execute(text('CREATE UNIQUE INDEX IF NOT EXISTS uq_collection_route_bin ON collection_events (route_id, bin_id)'))
from app.core.database import SessionLocal
from app.core.permissions import StaffGrant,legacy_grant
from app.models.access import RoleGrant
with SessionLocal() as db:
    for staff in db.query(StaffGrant):
        if not db.get(RoleGrant,'legacy:'+staff.user_id):db.add(legacy_grant(staff))
    db.commit()
print('Schema upgraded, scoped staff grants preserved. Legacy drivers retain their existing routes. Existing invoices are not automatically assigned to companies.')
