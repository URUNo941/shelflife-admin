# ShelfLife API

## Run

Set `JWT_SECRET` to a long, random secret in the backend process environment, then run `node server.js`. The database connection is configured in `db_config.js`; do not expose this development configuration in production. The API listens on port `3000` unless `PORT` is set.

## API routes

| Method | Route | Access |
|---|---|---|
| POST | `/api/auth/login` | Public |
| GET | `/api/items/:userId` | Existing inventory API |
| GET | `/api/items/item/:itemId` | Inventory API |
| POST | `/api/items` | Existing inventory API |
| PUT | `/api/items/item/:itemId` | Inventory API |
| DELETE | `/api/items/item/:itemId` | Inventory API |
| GET | `/api/products` | Public |
| GET | `/api/products/:productId` | Public |
| GET | `/api/products/master/:barcode` | Public |
| POST, PUT, DELETE | `/api/products` and `/api/products/:productId` | Admin bearer token |
| GET, POST, PUT, DELETE | `/api/users` and `/api/users/:userId` | Admin bearer token |

Send the login token as `Authorization: Bearer <token>` to protected routes. User responses omit password hashes; new and changed passwords are stored as Argon2 hashes.

The existing inventory endpoints remain unauthenticated for compatibility with the current Flutter client. Add authenticated user ownership checks and pass bearer tokens from the client before deploying this API beyond a trusted development environment.
