# Local government, contractor and bin testing

Open http://localhost:3000 with the backend running on port 8300.

## Government access

Create a normal account using Register. A system operator must then provision it; tapping a government menu does not grant privileges.

From the workspace root, replace YOUR_REGISTERED_PHONE with the canonical +234 phone number:

```powershell
./.venv/Scripts/python.exe scripts/manage_staff.py --phone YOUR_REGISTERED_PHONE --role platform_admin
```

For LGA-only access, use `--role lga_admin --lga-id YOUR_LGA_ID` after that LGA exists. No server restart is required for role changes.

Open Profile > State Dashboard. A platform administrator can Add LGA by name and state. Select the LGA from the dropdown. An LGA administrator sees only their assigned LGA.

## Add a physical smart bin

Use Add smart bin. Enter a unique printed code (maximum 20 characters), address, latitude and longitude. The selected LGA is saved with it. Saving persists a smart_bins record and displays its ID and printed code.

Example code: WP-TEST-001. For a test bin near the locator's current Lagos search area, use latitude 6.4550 and longitude 3.3841 with a clearly labelled test address. These are example coordinates, not a real installed bin.

Encode exactly the printed code, such as WP-TEST-001, in the QR sticker; do not encode a URL or JSON. QR sticker generation/printing is not included in this form. Attach the label only to the corresponding physical bin.

Use Find Bins > Find bin by code / Scan QR, or Deposit > Find bin / Scan QR. Manual lookup accepts either the printed code or the saved database ID. Scanning retrieves the same persisted bin. Choose Use this bin from Deposit to fill its ID and QR code automatically. Camera permission is required for scanning; manual lookup works without it.

The nearby list currently searches within 10 km of the Lagos default coordinates. Exact code lookup works for a registered bin anywhere.

Deposits stay pending; scanning alone does not award credits. Trusted telemetry and government verification are still required. Public lookup exposes the bin location, not personal or household records. Smart bin codes are not household billing account numbers.

## Register a contractor driver and truck

The driver first creates a normal account and copies User ID from Profile. Government staff open Profile > Contractor registration, select the LGA, and click Register contractor. Enter that user ID, a unique truck number and optional license plate. The existing backend registers the contractor and marks that user as a collector.

This form registers a driver/truck, not a corporate company registry. Driver access remains restricted to registered contractors. The dispatcher assigns routes through POST /contractors/dispatch in the local API docs at http://localhost:8300/docs; supply the contractor ID, LGA ID and persisted bin IDs. The driver then opens Profile > Contractor Driver App to see assigned routes.

## Checks

Backend: 21 API tests passed. Flutter: 6 widget tests passed; analyzer reports no issues. API tests use isolated in-memory databases. Local web and backend are development services.
