# WastePay access roles

Implemented in the repository root and wastepay_flutter.

| Role | Scope | Access |
| --- | --- | --- |
| Platform administrator | National | Manage roles, approve companies, operations and finance |
| Government supervisor | National, state or LGA | Read dashboards and reports in assigned areas |
| Government operations | National, state or LGA | Register bins, companies, consumer services and routes |
| Government finance | National, state or LGA | Issue invoices and authorize contractor settlement |
| LGA administrator | Assigned LGA | Operations and finance within that LGA |
| Contractor manager | Assigned company | Register vehicles and drivers, assign routes, monitor GPS, pickups and linked consumer invoice status |
| Driver | Active company membership and assigned routes | Share foreground GPS, submit collection evidence and report missed pickups |
| Consumer | Own account | Pay own invoices, request collection, view own service and collection status, report missed pickups |

The backend enforces permissions on every request. The Flutter menus follow the same permissions. Self-registration creates a consumer; it never grants staff access. Company dashboards do not expose another company, even when both operate in the same LGA. Government permissions are evaluated separately by function and area.

Payment and collection are independent. Paying an invoice does not verify collection. Collection verification retains the existing distance and sensor checks. Drivers cannot authorize settlement. Missed pickups require a reason; dispatchers can reassign unfinished work while audit events preserve the history. Driver location is foreground tracking and is marked stale after 90 seconds.

## Setup and migration

Back up the database, then run scripts/upgrade_database.py from the active backend directory. Existing accounts, legacy staff grants, drivers, routes and invoices are preserved. Revoked migrated grants stay revoked. Existing invoices are not guessed into companies, and legacy drivers are not automatically assigned to companies.

Use scripts/manage_staff.py --help to provision the first platform administrator. Subsequent staff access can be assigned through Profile > Role access. Company approval requires a registered manager user ID and approved LGAs; the manager can then register vehicles and registered users as drivers. Government operations staff create consumer services linking a consumer, company, LGA and registered bin. Finance staff issue invoices linked to those services. Managers can associate contracts, invoices and requested pickups with route stops.

## Local review

Open http://localhost:3000. Local-only ROLE_TEST_ACCOUNTS.md in the active backend contains generated phone numbers and passwords for ten demo accounts, including two isolated companies. Credentials and databases must stay out of Git. Demo bins WP-DEMO-A and WP-DEMO-B are fixtures, not physical installations. Scan verification needs real sensor evidence; bank transfer integration is not implemented by this role change.

## Verification

34 backend tests, 15 Flutter widget tests, and the same 15 tests in Chrome passed. Flutter analysis is clean. Tests cover tenant isolation, scoped permissions, suspension, migration preservation and independent collection/payment status.

## Contractor billing and receiving accounts

Customers use Home > Contractor to search approved companies by name and filter by state. Selecting a company is saved per customer; it does not transfer existing invoices or automatically create a service contract. Only that customer's linked invoices for the selected company are payable from this page. General customer dashboards display bills without direct payment buttons and no longer show wallet balances or financial transaction summaries.

Company managers complete onboarding using the receiving-bank/state button in their company dashboard. The state must match an approved company area. Bank codes come from Paystack; the account is resolved with the provider before a settlement subaccount is created. Account numbers are masked in profile responses, and audit events record only the last four digits. Raw debit card details are never stored in WastePay: customers enter them in Paystack checkout. Bank transfers also use provider checkout so confirmation can be reconciled to the exact invoice. Bank setup and real checkout require PAYSTACK_SECRET_KEY; no fake success or bank verification is supplied when it is missing.

Checkout passes the verified company subaccount using Paystack split payments with zero platform percentage and provider fees borne by the contractor. See https://paystack.com/docs/payments/split-payments/. Existing legacy government invoices keep their previous backend handling; the contractor page never guesses their recipient. Set up receiving accounts and issue a linked service invoice before testing real payments.
