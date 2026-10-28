# Offline history SQL tests

From the repository root, with Node.js and npm installed:

```sh
npm ci --prefix supabase/tests --ignore-scripts
node supabase/tests/run-offline-history.cjs
```

Run one suite independently:

```sh
node supabase/tests/run-offline-history.cjs offline_history_occurrences.sql
```

PGlite is pinned to **0.5.12** by `package.json` and `package-lock.json`.
No Docker daemon, database URL, credentials, Supabase project, or secrets are needed.
The runner creates a new **in-memory PostgreSQL engine for each suite**, closes it
on success or failure, and never opens a network connection to a database.
Dependency installation requires access to the npm registry (or an existing cache).
`node_modules/` is ignored locally by this directory's `.gitignore`.

## What is reproduced

The harness loads the actual original schema, the core RLS section of migration
02, the functions/triggers migration 03, and the reminder functions from migration 04
without its cron scheduling block. It provides minimal `auth.users` and
`auth.uid()` fixtures and the authenticated/anonymous roles. It grants read access
to the existing security-invoker balance view, as Supabase's default privileges do.
It loads the optional demo seed function from migration 05 without invoking it
until the demo suite. It does **not** emulate Supabase Storage, the cron scheduler,
PostgREST, or JWT signature
verification. Only the unrelated Storage portion of migration 02 is skipped; the
runner checks its source boundary so a changed file requires review.

`offline_history_seed.sql` runs before the new migration. Its independently known
initial state contains two users, wallet opening balances of 1,000 and 2,000,
income of 700, expense of 120, debt principal of 1,500 and paid debt of 700
(partial 200 plus settled 500). Expected total wallet balance is **3,580**.

The runner captures all original rows and wallet-by-wallet balances **before**
applying the new migration. Afterward it compares every original column, including
IDs, ownership and timestamps, and all monetary totals against that saved snapshot.
Only the newly added `version` and `deleted` columns are excluded from this original
row comparison. It separately checks that the two legacy payment rows sum to the
saved pre-migration paid amount and contain no linked cash transactions. This is
not a comparison between two values both derived after migration.

Each suite has `BEGIN` / `ROLLBACK`. Each runs on its own freshly bootstrapped engine.
After execution the runner also checks original rows and fixture/journal/op counts
against the baseline, as well as full row contents and versions across every synced
table, profiles, auth users, journal and op log, then closes that engine. Failures produce a nonzero exit code.

| Suite | Coverage |
| --- | --- |
| `offline_history.sql` | Replay, conflicts, auth, owner protection, notification restrictions, debt payment atomicity, undo, pagination |
| `offline_history_integration.sql` | Legacy edits/undo, natural-key reuse, category detachment, debt cascade, default payment notes/categories, balance view and goal deletion |
| `offline_history_occurrences.sql` | Atomic expense derivation, stale-device conflict, replay, linkage protection, failed-insert rollback, edit, undo/restore and payable/category cascades |
| `offline_history_demo.sql` | Fresh-only administrative demo seeding, reset/nonempty rejection, protected original helper, legacy history backfill and repeat-call preservation |

The runner also checks that the additive migration succeeds without the optional
demo seed function installed, preserving the pre-migration snapshot.

## Concurrency limitation

**Multi-session advisory-lock concurrency has not been executed.** PGlite exposes
one database connection per engine; separate engines are separate databases and
cannot establish the required shared-lock test. `offline_history_concurrency.sql`
contains a manual two-session schedule for a **disposable PostgreSQL test copy**.
The runner deliberately does not count that instruction file as a passing suite.
It verifies stale versions and replay sequentially, which is not a substitute for
running that schedule. No running local database is used by these tests.

## Exact RPC contract

```sql
public.sync_push(
  op_id uuid, entity text, record_id uuid, base_version bigint,
  payload jsonb, deleted bool
) returns jsonb

public.sync_pull(cursor bigint, "limit" int default 500) returns jsonb

public.settle_debt(
  p_debt_id uuid, p_amount bigint default null,
  p_record_transaction boolean default false, p_wallet_id uuid default null
) returns public.debts
```

Arguments to sync RPCs are **unprefixed**. Push returns
`{status,row,version}` with status `applied`, `conflict`, or `not_found`.
Pull returns `{changes:[{seq,entity,id,row,version,deleted}],cursor,has_more}`.
Create uses `base_version=0`; update/undo uses the current server version.
Retry the same operation with its original `op_id` and exact original arguments;
reusing that ID with a different request is rejected. Conflicts are also logged:
a subsequent resolved operation needs a new `op_id`.

Normal payloads contain only writable fields: strip `id,user_id,version,deleted,
created_at,updated_at,is_legacy` and debt `paid_amount,status`. Send deletion as the
separate `deleted` argument. Notification payloads may contain a full cached row:
only `is_read` is applied to an existing owned notification. Notifications cannot
be created or deleted through push. Owner identity always comes from `auth.uid()`.
Profiles are outside this journal. Authenticated direct writes to versioned tables
are revoked; use push or the backward-compatible settle RPC.

## Exact added schema / client coordination

All synchronized tables (`wallets,categories,transactions,budgets,debts,goals,
debt_payments,payables,payable_occurrences,category_rules,notifications`) have
`version bigint NOT NULL DEFAULT 1` and `deleted boolean NOT NULL DEFAULT false`.
New entity tables have `id uuid` primary key default `gen_random_uuid()`,
`user_id uuid NOT NULL DEFAULT auth.uid()`, and nonnull `created_at,updated_at`
`timestamptz DEFAULT now()`. Notifications also gain `updated_at`.
Server triggers increment versions and replace update timestamps.

| Table | Entity fields, beyond the shared columns |
| --- | --- |
| `debt_payments` | `debt_id uuid NOT NULL`, `amount bigint NOT NULL >0`, `paid_at timestamptz NOT NULL DEFAULT now()`, `note text NULL`, `record_transaction boolean NOT NULL DEFAULT false`, `wallet_id uuid NULL`, `transaction_id uuid NULL UNIQUE`, `is_legacy boolean NOT NULL DEFAULT false` |
| `payables` | `name text NOT NULL`, `amount bigint NOT NULL >0`, `due_date date NOT NULL`, `recurrence text NOT NULL DEFAULT 'none'` in `none,weekly,monthly,yearly`, `category_id uuid NULL`, `wallet_id uuid NULL`, `note text NULL`, `enabled boolean NOT NULL DEFAULT true` |
| `payable_occurrences` | `payable_id uuid NOT NULL`, `due_date date NOT NULL`, `amount bigint NOT NULL >0`, `status text NOT NULL DEFAULT 'pending'` in `pending,paid,skipped`, `paid_at timestamptz NULL`, `transaction_id uuid NULL UNIQUE`, `wallet_id uuid NULL`, `category_id uuid NULL`, `note text NULL` |
| `category_rules` | `keyword text NOT NULL` (nonblank), `merchant text NULL`, `category_id uuid NULL`, `enabled boolean NOT NULL DEFAULT true` |

References enforce owner-scoped foreign keys. Push rejects live references to
tombstones. Occurrence recorded categories must be expense categories.
Category deletion soft-deletes its rules, retaining their category linkage.

Queue **only a debt payment or payable occurrence**, never its derived transaction.
A recorded debt payment requires `record_transaction=true` and `wallet_id`;
its transaction UUID can be supplied at creation or generated by the server.
Debt parent and transaction linkage are immutable. Legacy payments keep
`is_legacy=true`; amount/date edits and undo recalculate debt totals but cannot
create cash movements. Default linked debt transaction notes are `Trả nợ {person}`
or `Thu nợ từ {person}`, with categories `Cho vay & Trả nợ` / `Thu nợ` when present.

For a recorded occurrence, the client supplies a deterministic `transaction_id`
derived from the occurrence ID (the server accepts the supplied UUID; it does not
compute or enforce a UUID derivation algorithm), plus `wallet_id` and optional
`category_id`. A nonnull transaction ID without an explicit status implies `paid`.
`paid_at` defaults to server time for recorded paid occurrences; a null note uses
the payable name for the expense note. The derived transaction uses
`type='expense'`, `source='manual'`. Occurrence parent is immutable. A transaction
can be attached later to an unrecorded occurrence, but once attached its UUID
cannot be replaced or cleared. Setting status to `pending` or `skipped`, or
soft-deleting the occurrence, tombstones the transaction; restoring `paid` restores
that same transaction. A newly attached transaction requires a live paid occurrence.
Direct pushes to debt/occurrence-linked transactions are rejected.

Deleting a debt first tombstones its payments and their transactions. Deleting a
payable tombstones its occurrences and linked expenses. Restoring a parent alone
does not automatically restore children. Category deletion always soft-deletes its
budgets and category rules, retaining their category linkage. It detaches live
transactions, payables and occurrences. It never converts a category budget into
an overall budget. Natural-key uniqueness excludes tombstones for
category `(user_id,type,name)`, budget `(user_id,category_id,month)` with nulls
not distinct, and occurrence `(payable_id,due_date)`. Wallet names remain nonunique,
as in the original schema, preserving existing duplicates.




## Administrative demo seeding

`private.seed_demo_data(p_email text, p_reset boolean DEFAULT false) RETURNS text`
is administrative-only and exists only if the optional original seed migration
was installed. **Use a fresh demo account only; never reset an account.**
`p_reset=true` (or null), nonempty financial/history/notification data, sync ops,
quota usage, altered wallets/categories and repeat seeding are rejected before
any seed writes. A fresh account means its original zero-balance cash wallet and
22 untouched signup categories, with no other application data.

The original implementation is renamed `private.seed_demo_data_v1(text,boolean)`
and has no public/anonymous/authenticated execute permission. The wrapper always
calls it with `p_reset=false` under the user transaction advisory lock. Its budget
conflict clause is adapted to the live-only index. Seeded positive `paid_amount`
values become `is_legacy=true` debt payments, with no wallet or transaction link.
The wrapper verifies each debt's history total and unchanged cash transaction
counts/income/expense across the backfill. All writes are journaled and atomic;
failure rolls back the whole seed. The helper is a privileged implementation
detail, never a client API or an approved way to reset existing data.

## Debt payment editing regression

The harness also loads `20261028000002_debt_payment_editing.sql` before every
suite, with the same pre/post monetary and row integrity checks.
`debt_payment_editing.sql` covers first attachment, immutable existing IDs,
note/date/wallet updates, recording off/on, archived wallets, optimistic
conflicts, replay, overpayment rollback and undo.

For real simultaneous sessions, start the local Supabase Docker stack, apply
all migrations, then run from the repository root:

```sh
node supabase/tests/run-debt-concurrency.cjs
```

This command targets only `supabase_db_tui-khon`, creates a uniquely identified
disposable account, and cleans only its fixtures in `finally`. It tests
simultaneous payments, stale edits and identical operation retries.
The in-memory runner does not claim to test multi-session concurrency.
