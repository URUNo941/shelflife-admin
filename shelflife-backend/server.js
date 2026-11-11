require("dotenv").config();
const app = require("./app");
const pool = require("./db_config");
async function start() {
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32)
    throw new Error("Set JWT_SECRET to at least 32 random characters.");
  await pool.query("SELECT 1");
  const server = app.listen(process.env.PORT || 3000, () =>
    console.log("ShelfLife API ready."),
  );
  for (const signal of ["SIGTERM", "SIGINT"])
    process.on(signal, () =>
      server.close(async () => {
        await pool.end();
        process.exit(0);
      }),
    );
}
start().catch(() => {
  console.error(
    "Startup failed. Check database and authentication configuration.",
  );
  process.exit(1);
});
