from fastapi import Depends, HTTPException
from sqlalchemy import Column, String, ForeignKey
from sqlalchemy.orm import Session
from app.core.database import Base, get_db
from app.routers.auth import get_current_user
from app.models.models import User
class StaffGrant(Base):
    __tablename__ = "staff_grants"
    user_id = Column(String, ForeignKey("users.id"), primary_key=True)
    role = Column(String, nullable=False)
    lga_id = Column(String, ForeignKey("lgas.id"), nullable=True)
def require_admin(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    grant = db.get(StaffGrant, user.id)
    if not grant or grant.role not in ("platform_admin", "lga_admin"):
        raise HTTPException(403, "Government administrator access required")
    return grant
def check_lga(grant, lga_id):
    if grant.role != "platform_admin" and grant.lga_id != lga_id:
        raise HTTPException(403, "Outside your assigned LGA")
