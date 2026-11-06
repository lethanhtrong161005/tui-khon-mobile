// Real PostgreSQL sessions against the local Docker container only.
// Creates a unique disposable user and deletes only that user's test data.
const { spawn, execFileSync } = require('node:child_process');
const { randomUUID } = require('node:crypto');
const assert = require('node:assert/strict');
const args = ['exec', '-i', 'supabase_db_tui-khon', 'psql', '-U', 'postgres', '-d', 'postgres', '-At', '-v', 'ON_ERROR_STOP=1'];
const uid = randomUUID(), debt = randomUUID(), payment = randomUUID(), otherDebt = randomUUID(), otherPayment = randomUUID();
const sql = s => execFileSync('docker', args, { input: s, encoding: 'utf8' });
const auth = `set local request.jwt.claim.sub='${uid}';set local role authenticated;`;
const push = (entity, id, version, payload, op = randomUUID()) => `select public.sync_push('${op}','${entity}','${id}',${version},'${JSON.stringify(payload)}',false);`;
function session(s, onLocked = () => {}) {
  const child = spawn('docker', args); let output = '', error = ''; let signalled = false;
  child.stdout.on('data', b => { output += b; if (!signalled && output.includes('LOCKED')) { signalled = true; onLocked(); } });
  child.stderr.on('data', b => error += b);
  child.stdin.end(s);
  return new Promise((resolve, reject) => {
    child.on('error', reject); child.on('close', code => resolve({ code, output, error }));
  });
}
async function race(first, second) {
  let unlock; const locked = new Promise(r => unlock = r);
  const a = session(`begin;${auth}${first}select 'LOCKED';select pg_sleep(1);commit;`, unlock);
  await Promise.race([locked, a.then(() => { throw Error('First session failed before obtaining lock'); })]);
  const b = session(`begin;${auth}${second}commit;`);
  return Promise.all([a, b]);
}
(async () => {
  try {
    sql(`insert into auth.users(id,email) values('${uid}','debt-${uid}@test.invalid');
      begin;${auth}${push('debts', debt, 0, { type: 'borrow', person_name: 'Concurrency QA', amount: 1000 })}
      ${push('debts', otherDebt, 0, { type: 'lend', person_name: 'Edit QA', amount: 1000 })}
      ${push('debt_payments', otherPayment, 0, { debt_id: otherDebt, amount: 200 })}commit;`);
    const wallet = sql(`select id from public.wallets where user_id='${uid}' limit 1;`).trim();
    const [a,b] = await race(push('debt_payments', payment, 0, { debt_id: debt, amount: 700, record_transaction: true, wallet_id: wallet }),
      push('debt_payments', randomUUID(), 0, { debt_id: debt, amount: 500, record_transaction: true, wallet_id: wallet }));
    assert.equal(a.code, 0, a.error); assert.notEqual(b.code, 0); assert.match(b.error, /exceeds remaining debt/);
    assert.equal(sql(`select paid_amount from public.debts where id='${debt}';`).trim(), '700');
    assert.equal(sql(`select count(*)::text||':'||sum(amount)::text from public.transactions where user_id='${uid}' and source='debt';`).trim(), '1:700');
    console.log('PASS simultaneous payments: overpayment rejected without clamping or partial cash changes');
    const [c,d] = await race(push('debt_payments', otherPayment, 1, { amount: 300 }), push('debt_payments', otherPayment, 1, { amount: 400 }));
    assert.equal(c.code, 0, c.error); assert.equal(d.code, 0, d.error); assert.match(d.output, /"status": "conflict"/);
    assert.equal(sql(`select amount from public.debt_payments where id='${otherPayment}';`).trim(), '300');
    console.log('PASS simultaneous edits: second device receives conflict, first amount preserved');
    const id = randomUUID(), op = randomUUID(); const request = push('debt_payments', id, 0, { debt_id: debt, amount: 100, record_transaction: true, wallet_id: wallet }, op);
    const [e,f] = await race(request, request);
    assert.equal(e.code, 0, e.error); assert.equal(f.code, 0, f.error);
    assert.equal(sql(`select count(*) from public.debt_payments where id='${id}';`).trim(), '1');
    assert.equal(sql(`select paid_amount from public.debts where id='${debt}';`).trim(), '800');
    assert.equal(sql(`select count(*)::text||':'||sum(amount)::text from public.transactions where user_id='${uid}' and source='debt';`).trim(), '2:800');
    console.log('PASS simultaneous retries: operation id creates exactly one payment');
  } finally {
    sql(`delete from auth.users where id='${uid}';delete from private.sync_changes where user_id='${uid}';delete from private.sync_ops where user_id='${uid}';`);
    console.log('Disposable concurrency fixture cleaned; existing users untouched.');
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
