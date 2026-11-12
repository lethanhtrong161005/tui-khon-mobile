import { validatePlan } from "./plan.ts";
const base = { kind: "summary", from: "2026-11-01", to: "2026-12-01" };
const categories = [{ id: "food" }], wallets = [{ id: "cash" }];
Deno.test("read-only query plan validates identifiers, kinds and calendar boundaries", () => {
  const plan = validatePlan(
    {
      ...base,
      category_id: "food",
      wallet_id: "cash",
      sql: "delete from transactions",
    },
    categories,
    wallets,
  );
  if (plan.kind !== "summary" || "sql" in plan) throw new Error("unsafe plan");
  for (
    const mutation of [
      { kind: "delete" },
      { from: "2026-02-31" },
      { to: "2026-01-01" },
      { wallet_id: "foreign" },
      { type: "transfer" },
      { overdue_only: "yes" },
      { search: 33 },
    ]
  ) {
    let rejected = false;
    try {
      validatePlan({ ...base, ...mutation }, categories, wallets);
    } catch {
      rejected = true;
    }
    if (!rejected) throw new Error("invalid plan accepted");
  }
});
