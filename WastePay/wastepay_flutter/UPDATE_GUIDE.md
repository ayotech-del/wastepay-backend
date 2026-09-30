# WastePay code update — September 30, 2026

The two project archives extend the supplied FastAPI and Flutter code. The government proposal is unchanged. This is a tested backend development update with Flutter source changes, not a production release or a deployed service.

## What changed

- Authenticated citizen profiles; normalized Nigerian phone numbers with legacy local-format login support.
- Government roles provisioned by an operator, with LGA access boundaries. Public registration cannot grant government access.
- Invoice payments verify ownership, positive amounts and available credits, and deduct wallet funds in the same database transaction as the payment record.
- Paystack checkout stores its payment intent locally. Verification and signed webhook callbacks share an atomic settlement path, preventing repeated callbacks from crediting a wallet twice. The raw payload is checked using Paystack's HMAC-SHA512 signature format. Provider metadata cannot choose a recipient or amount.
- Persistent bin search, bin status, authenticated telemetry and 75% fill alerts.
- Collection verification requires route ownership, assigned bin, matching QR, location within 100 metres and recent trusted before/after weight readings. The server calculates collected weight; it ignores client weight claims. Duplicate route/bin collections and reused sensor readings are rejected.
- Deposits remain pending until an LGA administrator verifies matching QR and trusted sensor weight increase. Verified credits are awarded once, with verifier and reading recorded.
- Contractor payment authorization requires every assigned bin to be verified. It records `awaiting_disbursement`; it does not claim a bank payment occurred.
- Persistent pickup requests with citizen-only history.
- Government summary and transaction CSV endpoints. CSV exports are general operational reports, not certified CBN/FMEnv compliance exports.
- Flutter bills/pickup screen, API-backed government overview, assigned route QR scanning and device GPS checks. Foreground GPS sends every 30 seconds while the route screen is open and stops when the app is paused or the screen closes.
- Flutter token refresh replays requests with the new token. Nearby bins use real backend results instead of replacing empty/error results with demonstration data.
- Missing font/asset references removed. API URL can be set with `--dart-define=API_BASE_URL=...`.

## Run the Python backend on Windows

Extract `wastepay-backend-main.zip`, then open PowerShell in its `wastepay-backend-main` folder:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
python scripts/railway_setup.py
python scripts/upgrade_database.py
python -m uvicorn app.main:app --host 0.0.0.0 --port 8300
```

API documentation: http://localhost:8300/docs

For an existing database, back it up before the upgrade and run in a maintenance window. The upgrade creates new tables and enforces unique route/bin collections. It stops if historical duplicate collections exist and does not delete them. It cannot retrospectively repair previously inflated balances, unsigned callbacks or false payment records; reconcile those separately before deployment.

Set `DATABASE_URL` to your actual PostgreSQL connection string to use PostgreSQL. SQLite is for local development. The startup creates missing tables; the explicit upgrade is still required for uniqueness on an existing database.

Register an administrator account through the app or `/auth/register`, then provision it from the backend directory:

```powershell
python scripts/manage_staff.py --phone "YOUR_PHONE_NUMBER" --role lga_admin --lga-id "YOUR_REAL_LGA_ID"
```

Use `/government/lgas` to find existing LGA IDs. A platform administrator can be provisioned with `--role platform_admin`. Keep this command restricted to trusted system operators.

For telemetry, set a strong random `TELEMETRY_KEY` in `.env` and restart. Your trusted sensor bridge must post to `/bins/telemetry` with the `X-Telemetry-Key` header and a body such as:

```json
{"bin_code":"YOUR_BIN_CODE","weight_kg":100.5,"fill_percent":80}
```

The weight readings are timestamped when received. A bridge must send fresh chronological readings, keep the key secret, use HTTPS, and must not replay or batch historical measurements as current readings. An MQTT broker/consumer is not included; this endpoint is the bridge integration point. GPS from a phone is evidence of proximity, not hardware-backed proof against GPS spoofing. Real-world calibration, device authentication and anti-tamper measures still need field validation.

## Run Flutter

The uploaded app contains Dart source, not a complete generated Android/iOS project. Extract `WastePay_Flutter_App.zip`; in `wastepay_flutter`, run:

```powershell
flutter create --platforms=android,ios --project-name=wastepay .
flutter pub get
flutter analyze
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8300
```

Android emulator: `10.0.2.2` reaches the host PC. Physical Android phone: use `adb reverse tcp:8300 tcp:8300` and `API_BASE_URL=http://localhost:8300`. iOS simulator on a Mac: use `http://localhost:8300`. Building/running iOS requires macOS and Xcode. Production URLs must use HTTPS.

After generating platform folders, configure permissions:

- Android `android/app/src/main/AndroidManifest.xml`: INTERNET, CAMERA, ACCESS_FINE_LOCATION and ACCESS_COARSE_LOCATION permissions. Permit local HTTP only in a development/debug manifest if required.
- iOS `ios/Runner/Info.plist`: NSCameraUsageDescription and NSLocationWhenInUseUsageDescription with a clear explanation to users.
- Existing Google Maps screens require your Maps API key in Android and iOS platform configuration.
- Firebase push notifications require separate Firebase application configuration; they were not integrated or tested in this update.

Use **Bills & pickup** on Home for assigned bills and pickup requests. Profile routes payment links to this screen, government access to the real summary screen, and contractor access to the real assigned-route screen. The old demonstration screens are retained as source for future design work; they must not be used as evidence of operational data or payment success.

For collection, a dispatcher first registers the contractor and assigns real bins using authenticated `/contractors/register` and `/contractors/dispatch`. The driver signs into their own account, opens Contractor Access, scans the physical bin QR (its exact `bin_code`), and captures device location. Trusted sensor readings must confirm a weight drop within the allowed time window. Manually entered weight is never accepted as payment evidence.

For deposits, enter a real bin ID and QR code. A staff operator calls `/waste/deposit/{deposit_id}/verify` after trusted sensor readings confirm the deposited weight. Citizen weight entries alone do not award credits.

## Verification and limits

The backend includes automated API tests for registration/login, invoice ownership and wallet deduction, invalid amounts, access controls, pickup privacy, pending deposits, sensor-backed collection, recycling awards, government metrics, signature rejection, repeated webhook/verification handling and amount/currency mismatch rollback. Run from the backend folder:

```powershell
python -m pytest -q tests
```

Flutter SDK was unavailable in the execution environment. Flutter source was checked for local imports, but `flutter analyze`, device builds, camera/GPS permission behavior and plugin compatibility could not be executed here. Test these on your emulator and real devices before release. PostgreSQL concurrency and real provider callbacks also require staging validation; automated tests use an isolated SQLite database and mocked provider responses.

KYC, bank disbursement and utility redemption intentionally return HTTP 503 without changing balances until proper providers are integrated. USSD, SMS reminders, background location, a full government web dashboard, Power BI, carbon accounting and compliance-certified reporting are not implemented in this update. HTTP telemetry is implemented; MQTT transport is not.

Before public deployment, complete provider integrations, migration/reconciliation review, rate limiting, token revocation/refresh rotation, security review, backups, operational monitoring, device testing, privacy controls for NIN/bank data and regulatory review. Set a generated `SECRET_KEY`, `ENVIRONMENT=production`, HTTPS, restricted `CORS_ORIGINS` and real PostgreSQL credentials. Never commit `.env` or provider keys.

Provider reference: https://paystack.com/docs/payments/webhooks/

## Public GitHub copy

Embedded contact examples have been replaced with placeholders. No default administrator password is supplied and no administrator account is seeded. Register your own user, then provision it with manage_staff.py.

For local development, the backend generates an ephemeral signing key if SECRET_KEY is blank; restarting invalidates tokens. For a persistent key, run `python -c "import secrets; print(secrets.token_urlsafe(48))"`, put the result in your local .env SECRET_KEY, and never commit it. Production requires an explicitly configured key.
