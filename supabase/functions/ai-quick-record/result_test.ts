import { type AiDraft, buildMultiResult } from "./result.ts";

const ctx = {
  categories: [{ id: "food", name: "Food", type: "expense" as const }],
  wallets: [{ id: "cash", name: "Cash", type: "cash" }],
  text: "coffee 35k; books",
  today: "2026-10-28",
  source: "ai",
};
const draft = (extra: Partial<AiDraft> = {}): AiDraft => ({
  is_transaction: true,
  type: "expense",
  amount: 35000,
  category: "Food",
  note: "Coffee",
  date: ctx.today,
  confidence: 0.9,
  source_text: "coffee 35k",
  missing_fields: [],
  ...extra,
});
function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${JSON.stringify(actual)} != ${JSON.stringify(expected)}`);
  }
}
Deno.test("complete and missing-amount items survive independently", () => {
  const result = buildMultiResult([
    draft(),
    draft({
      amount: 0,
      source_text: "books",
      note: "Books",
      missing_fields: ["amount"],
      question: "How much for books?",
    }),
  ], ctx);
  equal(result.drafts.map((d) => d.amount), [35000, 0]);
  equal(result.items[0].question, null);
  equal(result.items[1].source_text, "books");
  equal(result.items[1].missing_fields, ["amount"]);
  equal(result.items[1].question, "How much for books?");
});
Deno.test("ambiguous bare amount is never silently multiplied", () => {
  const result = buildMultiResult([
    draft({ source_text: "phở 65", amount: 65000 }),
  ], { ...ctx, text: "phở 65" });
  equal(result.drafts[0].amount, 0);
  equal(result.items[0].missing_fields, ["amount"]);
  if (!result.items[0].question) throw new Error("Expected a clarification");
});
Deno.test("explicit amount and a maximum of ten items", () => {
  const result = buildMultiResult(
    Array.from({ length: 12 }, () => draft()),
    ctx,
  );
  equal(result.items.length, 10);
  equal(result.drafts[0].amount, 35000);
});
