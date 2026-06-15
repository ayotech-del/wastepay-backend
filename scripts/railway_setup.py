#!/usr/bin/env python3
"""
WastePay Nigeria — Railway Production Setup Script
Run this once after first Railway deploy to initialize the database.

Usage:
  python scripts/railway_setup.py
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import Base, engine, SessionLocal
import app.models.models as M
import uuid

def create_tables():
    print("📦 Creating database tables...")
    Base.metadata.create_all(bind=engine)
    print(f"   ✅ Tables: {list(Base.metadata.tables.keys())}")

def seed_credit_rates(db):
    print("\n💰 Seeding credit rates...")
    rates = [
        (M.WasteType.PLASTIC,      400.0),
        (M.WasteType.PAPER,        300.0),
        (M.WasteType.GLASS,        150.0),
        (M.WasteType.METAL,        600.0),
        (M.WasteType.ORGANIC,       80.0),
        (M.WasteType.ELECTRONICS, 1200.0),
        (M.WasteType.MIXED,        100.0),
    ]
    for wtype, rate in rates:
        existing = db.query(M.CreditRate).filter(M.CreditRate.waste_type == wtype).first()
        if not existing:
            db.add(M.CreditRate(id=str(uuid.uuid4()), waste_type=wtype, ngn_per_kg=rate))
            print(f"   ✅ {wtype.value:12s} → ₦{rate}/kg")
        else:
            print(f"   ⏭  {wtype.value:12s} already set")
    db.commit()

def seed_lgas(db):
    print("\n🏛️  Seeding LGAs...")
    lgas = [
        # Lagos
        ("Eti-Osa", "Lagos", 2_000_000.0),
        ("Lagos Island", "Lagos", 1_500_000.0),
        ("Lagos Mainland", "Lagos", 1_200_000.0),
        ("Surulere", "Lagos", 1_000_000.0),
        ("Alimosho", "Lagos", 800_000.0),
        # Abuja
        ("AMAC (Abuja Municipal)", "FCT Abuja", 2_000_000.0),
        ("Bwari", "FCT Abuja", 800_000.0),
        # Rivers
        ("Port Harcourt City", "Rivers", 1_500_000.0),
        ("Obio/Akpor", "Rivers", 1_000_000.0),
        # Kano
        ("Kano Municipal", "Kano", 1_200_000.0),
    ]
    for name, state, fee in lgas:
        existing = db.query(M.LGA).filter(M.LGA.name == name).first()
        if not existing:
            db.add(M.LGA(
                id=str(uuid.uuid4()),
                name=name,
                state=state,
                monthly_fee_ngn=fee,
                subscription_active=False,
            ))
            print(f"   ✅ {name} ({state}) — ₦{fee:,.0f}/month")
        else:
            print(f"   ⏭  {name} already exists")
    db.commit()

def seed_smart_bins(db):
    print("\n🗑️  Seeding demo smart bins...")
    # Get Lagos LGAs
    eti_osa = db.query(M.LGA).filter(M.LGA.name == "Eti-Osa").first()
    mainland = db.query(M.LGA).filter(M.LGA.name == "Lagos Mainland").first()
    amac = db.query(M.LGA).filter(M.LGA.name == "AMAC (Abuja Municipal)").first()

    bins_data = [
        # Lagos Lekki / Victoria Island
        ("BIN-LG-001", 6.4281,  3.4219,  "Lekki Phase 1, Lagos",        eti_osa,  15),
        ("BIN-LG-002", 6.4350,  3.4580,  "Victoria Island, Lagos",       eti_osa,  72),
        ("BIN-LG-003", 6.4500,  3.3841,  "Ajah Bus Stop, Lagos",         eti_osa,  33),
        ("BIN-LG-004", 6.4530,  3.3940,  "Sangotedo Market, Lagos",      eti_osa,  88),
        # Lagos Mainland / Yaba
        ("BIN-LG-005", 6.5095,  3.3711,  "Yaba Tech Cluster, Lagos",     mainland, 45),
        ("BIN-LG-006", 6.4698,  3.3540,  "Surulere Stadium, Lagos",      mainland, 60),
        # Abuja
        ("BIN-AB-001", 9.0579,  7.4951,  "Wuse 2 Market, Abuja",         amac,     22),
        ("BIN-AB-002", 9.0320,  7.4785,  "Maitama District, Abuja",      amac,     55),
        ("BIN-AB-003", 9.0750,  7.4975,  "Garki II, Abuja",              amac,     10),
    ]
    for code, lat, lng, addr, lga, fill in bins_data:
        existing = db.query(M.SmartBin).filter(M.SmartBin.bin_code == code).first()
        if not existing and lga:
            status = M.BinStatus.FULL if fill >= 85 else M.BinStatus.ACTIVE
            db.add(M.SmartBin(
                id=str(uuid.uuid4()),
                bin_code=code,
                latitude=lat,
                longitude=lng,
                address=addr,
                lga_id=lga.id,
                status=status,
                fill_percent=fill,
            ))
            icon = "🔴" if fill >= 85 else "🟡" if fill >= 50 else "🟢"
            print(f"   ✅ {code}  {icon} {fill}%  {addr[:40]}")
        else:
            print(f"   ⏭  {code} already exists")
    db.commit()

def create_admin_user(db):
    print("\n👤 Creating admin user...")
    from app.core.core import hash_password
    existing = db.query(M.User).filter(M.User.phone == "+2349000000001").first()
    if not existing:
        uid = str(uuid.uuid4())
        u = M.User(
            id=uid,
            phone="+2349000000001",
            full_name="WastePay Admin",
            email="admin@wastepay.ng",
            hashed_password=hash_password(os.getenv("ADMIN_PASSWORD", "ChangeMe_Prod_2026!")),
            kyc_tier=M.KYCTier.TIER_3,
            is_active=True,
        )
        db.add(u)
        db.flush()
        db.add(M.Wallet(id=str(uuid.uuid4()), user_id=uid))
        db.commit()
        print(f"   ✅ Admin user: +2349000000001 | email: admin@wastepay.ng")
        print(f"   ⚠️  Set ADMIN_PASSWORD env var before production deploy!")
    else:
        print("   ⏭  Admin user already exists")

if __name__ == "__main__":
    print("🚀 WastePay Nigeria — Railway Production Setup")
    print("=" * 50)
    print(f"   DB: {os.getenv('DATABASE_URL', 'SQLite (dev)')}")
    print("=" * 50)

    create_tables()
    db = SessionLocal()
    try:
        seed_credit_rates(db)
        seed_lgas(db)
        seed_smart_bins(db)
        create_admin_user(db)
    finally:
        db.close()

    print("\n" + "=" * 50)
    print("✅ Setup complete! WastePay Nigeria is ready.")
    print("=" * 50)
