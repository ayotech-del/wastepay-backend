from sqlalchemy import Column, String, Float, Integer, Boolean, DateTime, Enum, ForeignKey, Text, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base
import enum, uuid

def gen_id(): return str(uuid.uuid4())

class KYCTier(str, enum.Enum):
    TIER_1 = "tier_1"
    TIER_2 = "tier_2"
    TIER_3 = "tier_3"

class TransactionType(str, enum.Enum):
    CREDIT_EARNED = "credit_earned"
    CREDIT_REDEEMED = "credit_redeemed"
    LEVY_PAYMENT = "levy_payment"
    BANK_WITHDRAWAL = "bank_withdrawal"
    LGA_DISBURSEMENT = "lga_disbursement"

class WasteType(str, enum.Enum):
    PLASTIC = "plastic"
    PAPER = "paper"
    GLASS = "glass"
    METAL = "metal"
    ORGANIC = "organic"
    ELECTRONICS = "electronics"
    MIXED = "mixed"

class BinStatus(str, enum.Enum):
    ACTIVE = "active"
    FULL = "full"
    OFFLINE = "offline"
    MAINTENANCE = "maintenance"

class User(Base):
    __tablename__ = "users"
    id = Column(String, primary_key=True, default=gen_id)
    phone = Column(String(15), unique=True, nullable=False, index=True)
    email = Column(String(255), unique=True, nullable=True)
    full_name = Column(String(255), nullable=False)
    hashed_password = Column(String, nullable=False)
    kyc_tier = Column(Enum(KYCTier), default=KYCTier.TIER_1)
    nin = Column(String(11), unique=True, nullable=True)
    is_active = Column(Boolean, default=True)
    is_collector = Column(Boolean, default=False)
    lga_id = Column(String, ForeignKey("lgas.id"), nullable=True)
    fcm_token = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    wallet = relationship("Wallet", back_populates="user", uselist=False)
    deposits = relationship("WasteDeposit", back_populates="user", foreign_keys="WasteDeposit.user_id")
    transactions = relationship("Transaction", back_populates="user")

class Wallet(Base):
    __tablename__ = "wallets"
    id = Column(String, primary_key=True, default=gen_id)
    user_id = Column(String, ForeignKey("users.id"), unique=True, nullable=False)
    eco_credits = Column(Float, default=0.0)
    total_earned = Column(Float, default=0.0)
    total_redeemed = Column(Float, default=0.0)
    kg_deposited = Column(Float, default=0.0)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    user = relationship("User", back_populates="wallet")

class Transaction(Base):
    __tablename__ = "transactions"
    id = Column(String, primary_key=True, default=gen_id)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    type = Column(Enum(TransactionType), nullable=False)
    amount = Column(Float, nullable=False)
    reference = Column(String, unique=True, nullable=False)
    description = Column(String(500), nullable=True)
    paystack_ref = Column(String, nullable=True)
    status = Column(String, default="pending")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    user = relationship("User", back_populates="transactions")

class WasteDeposit(Base):
    __tablename__ = "waste_deposits"
    id = Column(String, primary_key=True, default=gen_id)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    bin_id = Column(String, ForeignKey("smart_bins.id"), nullable=True)
    waste_type = Column(Enum(WasteType), nullable=False)
    weight_kg = Column(Float, nullable=False)
    credit_value = Column(Float, nullable=False)
    verified = Column(Boolean, default=False)
    qr_scan_data = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    user = relationship("User", back_populates="deposits", foreign_keys=[user_id])

class LGA(Base):
    __tablename__ = "lgas"
    id = Column(String, primary_key=True, default=gen_id)
    name = Column(String(200), unique=True, nullable=False)
    state = Column(String(100), nullable=False)
    monthly_fee_ngn = Column(Float, default=500000.0)
    subscription_active = Column(Boolean, default=False)
    total_waste_kg = Column(Float, default=0.0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class SmartBin(Base):
    __tablename__ = "smart_bins"
    id = Column(String, primary_key=True, default=gen_id)
    bin_code = Column(String(20), unique=True, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    address = Column(String(500), nullable=False)
    lga_id = Column(String, ForeignKey("lgas.id"), nullable=True)
    status = Column(Enum(BinStatus), default=BinStatus.ACTIVE)
    fill_percent = Column(Integer, default=0)
    last_telemetry = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class CreditRate(Base):
    __tablename__ = "credit_rates"
    id = Column(String, primary_key=True, default=gen_id)
    waste_type = Column(Enum(WasteType), unique=True, nullable=False)
    ngn_per_kg = Column(Float, nullable=False)
