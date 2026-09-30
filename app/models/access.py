"""Organization, access and service records. New tables preserve legacy schemas."""
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, Float, ForeignKey, Text, UniqueConstraint
from app.core.database import Base
from app.models.models import gen_id

class RoleGrant(Base):
    __tablename__ = 'role_grants'
    id = Column(String, primary_key=True, default=gen_id)
    user_id = Column(String, ForeignKey('users.id'), nullable=False, index=True)
    role = Column(String, nullable=False)
    scope_kind = Column(String, nullable=False)
    scope_value = Column(String, nullable=True)
    active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class Company(Base):
    __tablename__ = 'contractor_companies'
    id = Column(String, primary_key=True, default=gen_id)
    name = Column(String(200), nullable=False)
    active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class CompanyArea(Base):
    __tablename__ = 'company_areas'
    __table_args__ = (UniqueConstraint('company_id','lga_id'),)
    id = Column(String, primary_key=True, default=gen_id)
    company_id = Column(String, ForeignKey('contractor_companies.id'), nullable=False)
    lga_id = Column(String, ForeignKey('lgas.id'), nullable=False)

class CompanyDriver(Base):
    __tablename__ = 'company_drivers'
    id = Column(String, primary_key=True, default=gen_id)
    company_id = Column(String, ForeignKey('contractor_companies.id'), nullable=False, index=True)
    contractor_id = Column(String, ForeignKey('contractors.id'), unique=True, nullable=False)
    active = Column(Boolean, nullable=False, default=True)

class Vehicle(Base):
    __tablename__ = 'company_vehicles'
    id = Column(String, primary_key=True, default=gen_id)
    company_id = Column(String, ForeignKey('contractor_companies.id'), nullable=False, index=True)
    truck_number = Column(String(20), unique=True, nullable=False)
    license_plate = Column(String(20))
    driver_id = Column(String, ForeignKey('company_drivers.id'), unique=True)
    capacity_tonnes = Column(Float, nullable=False, default=5)
    active = Column(Boolean, nullable=False, default=True)

class ServiceContract(Base):
    __tablename__ = 'service_contracts'
    id = Column(String, primary_key=True, default=gen_id)
    company_id = Column(String, ForeignKey('contractor_companies.id'), nullable=False, index=True)
    user_id = Column(String, ForeignKey('users.id'), nullable=False, index=True)
    lga_id = Column(String, ForeignKey('lgas.id'), nullable=False)
    household_ref = Column(String(80), unique=True, nullable=False)
    address = Column(String(500), nullable=False)
    bin_id = Column(String, ForeignKey('smart_bins.id'), nullable=False)
    active = Column(Boolean, nullable=False, default=True)

class ServiceInvoice(Base):
    __tablename__ = 'service_invoices'
    invoice_id = Column(String, ForeignKey('invoices.id'), primary_key=True)
    contract_id = Column(String, ForeignKey('service_contracts.id'), nullable=False)

class RouteAssignment(Base):
    __tablename__ = 'company_route_assignments'
    route_id = Column(String, ForeignKey('collection_routes.id'), primary_key=True)
    company_id = Column(String, ForeignKey('contractor_companies.id'), nullable=False, index=True)
    vehicle_id = Column(String, ForeignKey('company_vehicles.id'), nullable=False)

class CollectionJob(Base):
    __tablename__ = 'collection_jobs'
    __table_args__ = (UniqueConstraint('route_id','bin_id'),)
    id = Column(String, primary_key=True, default=gen_id)
    route_id = Column(String, ForeignKey('collection_routes.id'), nullable=False, index=True)
    company_id = Column(String, ForeignKey('contractor_companies.id'), nullable=False, index=True)
    bin_id = Column(String, ForeignKey('smart_bins.id'), nullable=False)
    contract_id = Column(String, ForeignKey('service_contracts.id'))
    invoice_id = Column(String, ForeignKey('invoices.id'))
    pickup_id = Column(String, ForeignKey('pickup_requests.id'), unique=True)
    status = Column(String, nullable=False, default='assigned')
    missed_reason = Column(String(1000))
    verified_at = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow)

class PickupContract(Base):
    __tablename__ = 'pickup_contracts'
    pickup_id = Column(String, ForeignKey('pickup_requests.id'), primary_key=True)
    contract_id = Column(String, ForeignKey('service_contracts.id'), nullable=False)

class AuditEvent(Base):
    __tablename__ = 'audit_events'
    id = Column(String, primary_key=True, default=gen_id)
    actor_id = Column(String, ForeignKey('users.id'), nullable=False)
    action = Column(String, nullable=False)
    resource_id = Column(String, nullable=False)
    lga_id = Column(String, ForeignKey('lgas.id'))
    company_id = Column(String, ForeignKey('contractor_companies.id'))
    details = Column(Text, nullable=False, default='{}')
    created_at = Column(DateTime, default=datetime.utcnow)

class CompanyBank(Base):
    __tablename__='company_bank_profiles'
    company_id=Column(String,ForeignKey('contractor_companies.id'),primary_key=True)
    state=Column(String(100),nullable=False)
    bank_name=Column(String(150),nullable=False)
    bank_code=Column(String(20),nullable=False)
    account_number=Column(String(10),nullable=False)
    account_name=Column(String(200),nullable=False)
    subaccount_code=Column(String(100))
    verified=Column(Boolean,nullable=False,default=False)

class CustomerContractor(Base):
    __tablename__='customer_contractor_preferences'
    user_id=Column(String,ForeignKey('users.id'),primary_key=True)
    company_id=Column(String,ForeignKey('contractor_companies.id'),nullable=False)
