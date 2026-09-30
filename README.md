# WastePay

FastAPI backend and Flutter app for waste deposits, billing, government operations and contractor collection.

The backend lives at the repository root. The updated Flutter project, including its web platform, lives in `wastepay_flutter/`. The older `wastepay_backend/` directory is a legacy copy; use the root backend for this update.

## Local setup on Windows

```powershell
py -3.12 -m venv .venv
./.venv/Scripts/python.exe -m pip install -r requirements.txt
./.venv/Scripts/python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8300
```

In a second terminal:

```powershell
Set-Location wastepay_flutter
flutter pub get
flutter run -d web-server --web-hostname localhost --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8300
```

Open http://localhost:3000. API documentation is at http://localhost:8300/docs. The backend allows localhost:3000 by default; configure CORS_ORIGINS when changing the frontend origin.

Register an account in the app. No default administrator credentials are supplied. See [LOCAL_TESTING.md](LOCAL_TESTING.md) for staff provisioning, LGA creation, contractor registration and saving/looking up bins.

## Updated behavior

- Profile menus open the government dashboard, contractor registration and assigned routes.
- Government accounts see their permitted LGAs. Platform administrators can create LGAs.
- Government staff can register a driver/truck and persist physical bins with a unique printed code, address and coordinates.
- Bin lookup accepts either a printed code or database ID. QR scanning resolves the saved bin and fills deposit details.
- Deposits remain pending until trusted sensor readings are verified. Scanning alone does not award credits.
- Signed Paystack settlement, invoice ownership checks, LGA boundaries and duplicate credit protection are enforced by the backend.

Contractor registration requires an existing driver account and government privileges. This is driver/truck registration, not a corporate company registry. QR sticker generation/printing is not included. Route dispatch currently uses the API. The nearby bin list currently searches the default Lagos area; exact lookup works anywhere.

## Validation

```powershell
./.venv/Scripts/python.exe -m pytest -q tests
Set-Location wastepay_flutter
flutter analyze
flutter test
flutter build web --dart-define=API_BASE_URL=http://localhost:8300
```

Verified on September 30, 2026: 21 backend tests and 6 Flutter widget tests passed; Flutter analysis reported no issues; the standard JavaScript web build succeeded. Dependencies currently report WebAssembly incompatibilities, so this verification does not cover a Wasm build. API tests use isolated SQLite databases and mocked provider responses.

See [UPDATE_GUIDE.md](UPDATE_GUIDE.md) for backend migration and integration limits, and [DEPLOY.md](DEPLOY.md) for deployment configuration. Flutter includes the web platform; mobile platform generation and device testing remain separate steps.

## Scoped roles and contractor billing

Government access is scoped by function and area. Company managers see their own fleet, routes and service invoices; drivers and consumers see their own work and bills. Customers select contractors by name/state, and managers complete receiving-bank setup before Paystack checkout is enabled. See [ACCESS_ROLES.md](ACCESS_ROLES.md) and [LOCAL_TESTING.md](LOCAL_TESTING.md). Real bank verification and checkout require Paystack configuration.
