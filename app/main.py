from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers.auth import router as auth_router
from app.routers.wallet import router as wallet_router
from app.routers.billing import router as billing_router
from app.routers.contractors import router as contractors_router
from app.routers.stubs import users_router, waste_router, bins_router, lga_router, webhooks_router, ussd_router

app = FastAPI(title="WastePay Nigeria API", description="Waste Management Payment System", version="2.0.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

app.include_router(auth_router,        prefix="/auth",        tags=["Auth"])
app.include_router(wallet_router,      prefix="/wallet",      tags=["Wallet"])
app.include_router(billing_router,     prefix="/billing",     tags=["Billing"])
app.include_router(contractors_router, prefix="/contractors", tags=["Contractors"])
app.include_router(users_router,       prefix="/users",       tags=["Users"])
app.include_router(waste_router,       prefix="/waste",       tags=["Waste"])
app.include_router(bins_router,        prefix="/bins",        tags=["Bins"])
app.include_router(lga_router,         prefix="/lga",         tags=["LGA"])
app.include_router(webhooks_router,    prefix="/webhooks",    tags=["Webhooks"])
app.include_router(ussd_router,        prefix="/ussd",        tags=["USSD"])

@app.get("/", tags=["Health"])
def root(): return {"status":"ok","service":"WastePay Nigeria API","version":"2.0.0"}

@app.get("/health", tags=["Health"])
def health(): return {"status":"healthy"}

@app.on_event("startup")
def startup():
    from app.core.database import Base, engine
    Base.metadata.create_all(bind=engine)
