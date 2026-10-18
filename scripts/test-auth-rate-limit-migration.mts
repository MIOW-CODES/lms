import assert from "node:assert/strict";
import { PGlite } from "@electric-sql/pglite";

const pg = new PGlite();
try {
  await pg.exec("CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;");
  const migration = await Bun.file(
    new URL("../supabase/migrations/20261018000008_shared_auth_rate_limits.sql", import.meta.url),
  ).text();
  await pg.exec(migration);

  const consume = () =>
    pg.query<{ allowed: boolean; remaining: number }>(
      "SELECT * FROM public.consume_auth_rate_attempt($1, $2, $3)",
      ["test-account", 2, 900],
    );
  assert.deepEqual((await consume()).rows[0], { allowed: true, remaining: 1 });
  assert.deepEqual((await consume()).rows[0], { allowed: true, remaining: 0 });
  assert.deepEqual((await consume()).rows[0], { allowed: false, remaining: 0 });

  for (let i = 0; i < 5; i++) {
    await pg.query("SELECT public.record_auth_rate_failure($1, $2)", ["hashed-identity", 900]);
  }
  const blocked = await pg.query<{ allowed: boolean; remaining: number }>(
    "SELECT * FROM public.check_auth_rate_limit($1, $2, $3)",
    ["hashed-identity", 5, 900],
  );
  assert.deepEqual(blocked.rows[0], { allowed: false, remaining: 0 });
  await pg.query("SELECT public.clear_auth_rate_limit($1)", ["hashed-identity"]);
  const cleared = await pg.query<{ allowed: boolean; remaining: number }>(
    "SELECT * FROM public.check_auth_rate_limit($1, $2, $3)",
    ["hashed-identity", 5, 900],
  );
  assert.deepEqual(cleared.rows[0], { allowed: true, remaining: 5 });
  console.info("Authentication rate-limit migration passed.");
} finally {
  await pg.close();
}
