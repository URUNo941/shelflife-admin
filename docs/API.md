# API and screen mapping

All JSON endpoints are under `/api`. Use `Authorization: Bearer <token>` after
login. Sessions are held in memory in Flutter and cleared on logout/401; restarting
the app requires login. Do not store tokens in browser localStorage. Use HTTPS
outside local development.

| Screen | Requests | Tables |
|---|---|---|
| Register | POST `/auth/register` `{username,email,password}` | users |
| Login | POST `/auth/login` `{username,password}` → `{token,user}` | users |
| Profile | GET `/auth/me` or `/me`; login response supplies displayed profile | users |
| Inventory / Home | GET `/me/inventory` (`status=active` default; `all`, `consumed`, `discarded` supported) | inventory_items |
| Add/edit batch | POST `/me/inventory`, PATCH `/me/inventory/:itemId` | inventory_items, inventory_events, global_products, product_barcodes |
| Delete batch | DELETE `/me/inventory/:itemId` → 204; soft delete | inventory_items, inventory_events |
| Barcode scan/manual lookup | GET `/products/barcodes/:barcode`; unknown barcode → 404 and manual form entry | product_barcodes, global_products |
| Categories | GET `/categories` | categories |
| Catalog | GET/POST `/admin/products`, PATCH/DELETE `/admin/products/:productId` | global_products, categories, product_barcodes, audit_logs |
| User management | GET/POST `/admin/users`, GET/PATCH/DELETE `/admin/users/:userId` | users, audit_logs |
| Dashboard / Analytics | GET `/admin/analytics/summary?from=YYYY-MM-DD&to=YYYY-MM-DD` | users, global_products, inventory_items, inventory_events |

Inventory body: `product_name` (1–100 chars), `expiration_date` (real YYYY-MM-DD),
optional `barcode` (1–50 chars or null), `category` (1–50 chars), `quantity`
(1–2147483647 integer), `status` (active/consumed/discarded). Creation defaults to
General, quantity 1, active. Ownership comes exclusively from the authenticated
account; `user_id` and `product_id` in the body are rejected.

Catalog body: `barcode`, `product_name`, optional `category`. Admin user creation:
`username`, `password`, optional `email`, `role`. Public registration always creates
role user, regardless of a role supplied by the caller. Admin APIs re-read the
account's current role and active status for each request. Account deletion means
deactivation; the UI currently has no reactivation action. Self-demotion and
self-deactivation are rejected. Passwords are never included in responses.

Analytics totals are a **current snapshot**. The date filter applies only to the
event breakdown. Events start at the upgrade; absence of past events must not be
presented as zero past consumption. Quantity changes are signed active-stock deltas,
not revenue, waste cost or historical stock balances.

Compatibility aliases remain: `/items/:userId` GET requires that userId equals the
caller; `/items` POST and `/items/:itemId` PUT/PATCH/DELETE use the same protected
controller. `/products/master/:barcode`, product PUT and `/users` admin routes
remain. Old unauthenticated callers must upgrade. Item detail is available at
`/me/inventory/item/:itemId` or `/items/item/:itemId`.

Errors use `{message}`: 400 invalid input, 401 unauthenticated/inactive, 403 wrong
role/legacy owner URL, 404 absent or other owner's item, 409 duplicate, 429 auth
rate limit, 500 generic database failure. No SQL or credentials are returned.
The auth limiter is per process/IP (30 requests/15 minutes); multi-instance hosting
needs a shared limiter store and a reviewed reverse-proxy configuration.

The admin screens now use API-backed lists and current summary cards, replacing
the previous hard-coded charts. They include loading, retry, empty state, search,
mutation errors and deactivation confirmation. Password reset, persistent login,
email verification, profile editing and separate category/alias management remain
outside this implementation. Camera capture still requires device testing and
camera permission; barcode lookup itself is covered by API integration tests.
