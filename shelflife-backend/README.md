# ShelfLife API

See the [setup guide](../README.md), [API reference](../docs/API.md), and
[migration runbook](../docs/DATABASE_V2.md).

Run `npm ci`, configure a private `.env` from `.env.example`, apply `npm run migrate`
to a verified database copy, then run `npm start`.

`npm test` runs unit tests. Set `TEST_DB_HOST` and optional `TEST_DB_PORT`,
`TEST_DB_USER`, `TEST_DB_PASSWORD` to include isolated real-database integration.
All inventory routes require authentication and owner checks, including aliases.
