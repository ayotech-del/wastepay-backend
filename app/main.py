from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers.auth import router as auth_router
from app.routers.wallet import router as wallet_router
from app.routers.billing import router as billing_router
from app.routers.paystack import router as paystack_router
from app.routers.contractors import router as contractors_router
from app.routers.operations import users_router, waste_router, bins_router, pickups_router
from app.core.core import settings
from app.routers.paystack import router as webhooks_router

app = FastAPI(title="WastePay Nigeria API", description="Waste Management Payment System", version="2.1.0")

app.add_middleware(CORSMiddleware, allow_origins=[v.strip() for v in settings.CORS_ORIGINS.split(",") if v.strip()], allow_credentials=False, allow_methods=["*"], allow_headers=["*"])

app.include_router(auth_router,        prefix="/auth",        tags=["Auth"])
app.include_router(wallet_router,      prefix="/wallet",      tags=["Wallet"])
app.include_router(paystack_router, prefix="/paystack", tags=["Paystack"])
app.include_router(billing_router,     prefix="/billing",     tags=["Billing"])
app.include_router(contractors_router, prefix="/contractors", tags=["Contractors"])
app.include_router(users_router,       prefix="/users",       tags=["Users"])
app.include_router(waste_router,       prefix="/waste",       tags=["Waste"])
app.include_router(bins_router,        prefix="/bins",        tags=["Bins"])
app.include_router(pickups_router, prefix="/pickups", tags=["Pickups"])

from app.routers.paystack import webhook
app.add_api_route("/webhooks/paystack", webhook, methods=["POST"], tags=["Webhooks"])

from app.routers.government import router as government_router
app.include_router(government_router, prefix="/government", tags=["Government"])

@app.get("/", tags=["Health"])
def root(): return {"status":"ok","service":"WastePay Nigeria API","version":"2.1.0"}

@app.get("/health", tags=["Health"])
def health(): return {"status":"healthy"}

@app.on_event("startup")
def startup():
    from app.core.database import Base, engine
    Base.metadata.create_all(bind=engine)

