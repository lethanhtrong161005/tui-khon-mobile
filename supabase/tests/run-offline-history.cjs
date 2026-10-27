// Disposable in-memory PostgreSQL only. No URL, credentials, disk database, or Docker.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { PGlite } = require('@electric-sql/pglite');
const read = name => fs.readFileSync(path.join(__dirname, name), 'utf8').replace(/^\uFEFF/, '');
const migration = name => read('../migrations/' + name);
const suites = ['offline_history.sql', 'offline_history_integration.sql', 'offline_history_occurrences.sql', 'offline_history_demo.sql'];
const selected = process.argv.slice(2);
if (selected.some(name => !suites.includes(name))) {
  console.error('Usage: node run-offline-history.cjs [' + suites.join(' | ') + ']');
  process.exit(2);
}

async function bootstrap(db, includeDemo = true) {
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}');
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
    $$;
    grant usage on schema auth to authenticated;
    grant execute on function auth.uid() to authenticated;
  `);
  await db.exec(migration('20261024000001_init_schema.sql'));
  // Execute the real core RLS migration. Storage policies need Supabase Storage,
  // which this in-memory harness deliberately does not emulate.
  const rls = migration('20261024000002_rls_policies.sql');
  const boundary = rls.indexOf('-- Storage: bucket private');
  assert.ok(boundary > 0, 'Core RLS boundary changed: review the harness');
  await db.exec(rls.slice(0, boundary));
  await db.exec(migration('20261024000003_functions_triggers.sql'));
  // Load reminder functions without installing/scheduling pg_cron.
  const reminders = migration('20261024000004_debt_reminders_cron.sql');
  const scheduleBoundary = reminders.indexOf('-- 08:00');
  assert.ok(scheduleBoundary > 0, 'Cron boundary changed: review the harness');
  await db.exec(reminders.slice(0, scheduleBoundary));
  if (includeDemo) await db.exec(migration('20261024000005_demo_data.sql'));
  // Match Supabase default read privilege for its security_invoker view.
  await db.exec('grant select on public.wallet_balances to authenticated');
  await db.exec(read('offline_history_seed.sql'));
}

async function snapshot(db, migrated) {
  const rows = {};
  for (const table of ['wallets', 'categories', 'transactions', 'budgets', 'debts', 'goals']) {
    // Compare all original columns, including timestamps, ownership and IDs.
    const projection = migrated ? "to_jsonb(t)-'version'-'deleted'" : 'to_jsonb(t)';
    const result = await db.query(`select coalesce(jsonb_agg(${projection} order by t.id),'[]')::text as data from public.${table} t`);
    rows[table] = result.rows[0].data;
  }
  const money = await db.query(`select
    (select count(*)::text from public.transactions) as transaction_count,
    (select sum(amount)::text from public.transactions where type='income') as income,
    (select sum(amount)::text from public.transactions where type='expense') as expense,
    (select sum(amount)::text from public.debts) as debt_principal,
    (select sum(paid_amount)::text from public.debts) as debt_paid,
    (select sum(balance)::text from public.wallet_balances) as total_balance,
    (select jsonb_agg(jsonb_build_object('wallet_id',wallet_id,'balance',balance::text) order by wallet_id)::text from public.wallet_balances) as wallets`);
  return { rows, money: money.rows[0] };
}

async function fullState(db) {
  const state = {};
  for (const table of ['public.wallets','public.categories','public.transactions',
    'public.budgets','public.debts','public.goals','public.debt_payments',
    'public.payables','public.payable_occurrences','public.category_rules',
    'public.notifications','public.profiles','private.sync_changes','private.sync_ops','auth.users']) {
    const result = await db.query(`select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]')::text as data from ${table} t`);
    state[table] = result.rows[0].data;
  }
  return state;
}

async function run(suite) {
  // A fresh engine for EACH suite prevents role/session/fixture leakage.
  const db = new PGlite();
  try {
    await bootstrap(db);
    const before = await snapshot(db, false);
    assert.equal(before.money.transaction_count, '2');
    assert.equal(before.money.income, '700');
    assert.equal(before.money.expense, '120');
    assert.equal(before.money.debt_principal, '1500');
    assert.equal(before.money.debt_paid, '700');
    assert.equal(before.money.total_balance, '3580');
    await db.exec(migration('20261028000001_offline_history.sql'));
    assert.deepEqual(await snapshot(db, true), before, 'Migration changed original data or money totals');
    const history = await db.query(`select sum(amount)::text as paid,count(*)::text as count,
      bool_and(is_legacy and not record_transaction and transaction_id is null) as no_cash
      from public.debt_payments`);
    assert.deepEqual(history.rows[0], { paid: before.money.debt_paid, count: '2', no_cash: true });
    const baseline = await db.query(`select
      (select count(*)::text from private.sync_changes) as changes,
      (select count(*)::text from private.sync_ops) as ops,
      (select count(*)::text from auth.users) as users`);
    const fullBaseline = await fullState(db);
    const sql = read(suite);
    assert.match(sql.trim(), /^--[^]*?\bbegin;/i);
    assert.match(sql.trim(), /rollback;$/i);
    try { await db.exec(sql); }
    catch (error) {
      await db.exec('rollback; reset role;');
      throw error;
    }
    assert.deepEqual(await snapshot(db, true), before, 'Suite did not roll back original rows');
    const after = await db.query(`select
      (select count(*)::text from private.sync_changes) as changes,
      (select count(*)::text from private.sync_ops) as ops,
      (select count(*)::text from auth.users) as users`);
    assert.deepEqual(after.rows, baseline.rows, 'Suite leaked journal/op/user data');
    console.log(`PASS ${suite}: pre/post migration integrity + rollback isolation`);
  } finally { await db.close(); }
}
async function withoutOptionalSeeder() {
  const db = new PGlite();
  try {
    await bootstrap(db, false);
    const before = await snapshot(db, false);
    await db.exec(migration('20261028000001_offline_history.sql'));
    assert.deepEqual(await snapshot(db, true), before);
    const result = await db.query("select to_regprocedure('private.seed_demo_data(text,boolean)') is null as absent");
    assert.equal(result.rows[0].absent, true);
    console.log('PASS optional demo seeder absent: migration succeeds and preserves original data');
  } finally { await db.close(); }
}
(async () => {
  for (const suite of selected.length ? selected : suites) await run(suite);
  await withoutOptionalSeeder();
  console.log('Multi-session advisory-lock concurrency: NOT RUN (manual PostgreSQL schedule provided).');
})().catch(error => {
  console.error(error.message);
  if (error.where) console.error(error.where);
  if (error.internalQuery) console.error(error.internalQuery);
  process.exitCode = 1;
});




