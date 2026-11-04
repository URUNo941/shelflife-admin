# ShelfLife API

The API uses the `inventory_items`, `global_products`, and `users` tables in
MySQL. Set the database and JWT settings in a local `.env` file based on
`.env.example` before starting the server. The server binds to `127.0.0.1` by
default.

Start the API from this directory with `node server.js`. Create the first
administrator only when one does not already exist:

```powershell
$env:ADMIN_USERNAME = "admin"
$env:ADMIN_PASSWORD = "use-a-unique-password"
node scripts/create_admin.js
```

Authenticate with `POST /api/auth/login` using `{ "username": "...", "password":
"..." }`. Use its returned bearer token for the other API requests. Passwords
are hashed with Argon2 and are never included in user responses. User and product
management requires the administrator role; inventory operations are limited
to the owning user or an administrator. In Flutter, create the authenticated API
client with `ApiClient(accessToken: session.token)` after `UserController.login`.

| Entity | Routes |
| --- | --- |
| Inventory items | `GET /api/items/:userId`, `GET /api/items/:userId/:itemId`, `POST /api/items`, `PATCH /api/items/:itemId`, `DELETE /api/items/:itemId` |
| Global products | `GET /api/products`, `GET /api/products/:productId`, `GET /api/products/master/:barcode`, `POST /api/products`, `PATCH /api/products/:productId`, `DELETE /api/products/:productId` |
| Users | `GET /api/users`, `GET /api/users/:userId`, `POST /api/users`, `PATCH /api/users/:userId`, `DELETE /api/users/:userId` |

Inventory listing preserves the previous behavior of returning active items by
default. Pass `?include_inactive=true` to include consumed and discarded items.
