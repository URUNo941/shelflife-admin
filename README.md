# ShelfLife

Flutter inventory application with an Express/MySQL API, shared barcode catalog,
per-user batches, administrator tools and database-backed authentication.

## Local setup

Requirements: Node 22+, Flutter 3.47.5, MySQL 8.4 or MariaDB 10.11+.

1. Create or select your development database. For existing data, follow the
   [V2 migration runbook](docs/DATABASE_V2.md) and rehearse on a restored copy first.
2. In `shelflife-backend`, run `npm ci`. Copy `.env.example` to `.env` and configure
   the database account and a fresh random JWT secret of at least 32 characters.
   Use an account restricted to the application database; migration needs DDL
   permissions. Do not commit `.env` or backup files.
3. Run `npm run migrate`, then `npm start`. `/health` checks a real database query.
4. From the repository root, run:

   ```sh
   flutter pub get
   flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000/api
   ```

   `.env.example` allows `http://localhost:8080`. Set `CORS_ORIGINS` to a
   comma-separated list of exact frontend origins as needed. Android emulator uses
   `http://10.0.2.2:3000/api`; physical devices need a reachable HTTPS API. No
   production cleartext-network exception is enabled.
5. Register a real account. A database operator can explicitly grant that account
   the first admin role. Sample-dump placeholder password hashes do not work.

## Verification

```sh
cd shelflife-backend
npm test
```

Without `TEST_DB_HOST`, database integration is reported as skipped. For the full
suite set `TEST_DB_HOST`, `TEST_DB_PORT`, `TEST_DB_USER`, `TEST_DB_PASSWORD` for an
isolated server where that test account can create/drop databases. Each run creates
a random `shelflife_test_*` database, imports V1, migrates twice, exercises real HTTP
APIs and removes it. It never imports into the application's `DB_NAME`.

```sh
flutter analyze
flutter test
flutter build web
```

CI runs MySQL and MariaDB integration, Flutter analysis, tests and web build.
Local database validation used MariaDB 11.4.5. Device camera capture and Android/iOS
builds need their own acceptance pass.

## Design and rollout

- [Database, ER diagram, dictionary and migration](docs/DATABASE_V2.md)
- [API contracts and screen/table mapping](docs/API.md)

This upgrade removes tracked `.env` and `node_modules`. Any credentials previously
committed must be rotated by their owner; removing a file does not erase history.
No automatic production migration or deployment is included.
