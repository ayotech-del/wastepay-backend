"""WastePay Nigeria — FastAPI Backend"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers.auth import router as auth_router
from app.routers.wallet import router as wallet_router
from app.routers.stubs import (
    users_router, waste_router, bins_router,
    lga_router, webhooks_router, ussd_router
)

app = FastAPI(
    title="WastePay Nigeria API",
    description="Waste Management Payment System",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router,     prefix="/auth",     tags=["Authentication"])
app.include_router(wallet_router,   prefix="/wallet",   tags=["Wallet"])
app.include_router(users_router,    prefix="/users",    tags=["Users"])
app.include_router(waste_router,    prefix="/waste",    tags=["Waste Deposits"])
app.include_router(bins_router,     prefix="/bins",     tags=["Smart Bins"])
app.include_router(lga_router,      prefix="/lga",      tags=["LGA Portal"])
app.include_router(webhooks_router, prefix="/webhooks", tags=["Webhooks"])
app.include_router(ussd_router,     prefix="/ussd",     tags=["USSD"])

@app.get("/", tags=["Health"])
def root():
    return {"status": "ok", "service": "WastePay Nigeria API", "version": "1.0.0"}

@app.get("/health", tags=["Health"])
def health():
    return {"status": "healthy"}

@app.on_event("startup")
def startup():
    from app.core.database import Base, engine
    from app.models.models import (
        User, Wallet, Transaction, WasteDeposit,
        SmartBin, LGA, CreditRate
    )
    Base.metadata.create_all(bind=engine)
