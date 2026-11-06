import { advisorPeriod } from "./period.ts";

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

Deno.test("exact month and previous calendar month ignore today's date", () => {
  const p = advisorPeriod({ month: "2026-01-01" }, "2026-10-28");
  equal([p.from, p.to, p.prevFrom, p.prevTo, p.range], [
    "2026-01-01",
    "2026-01-31",
    "2025-12-01",
    "2025-12-31",
    31,
  ]);
});
Deno.test("leap February and non-leap February", () => {
  const leap = advisorPeriod({ month: "2024-02-01" }, "2026-10-28");
  equal([leap.to, leap.range], ["2024-02-29", 29]);
  const march = advisorPeriod({ month: "2026-03-01" }, "2026-10-28");
  equal([march.prevFrom, march.prevTo], ["2026-02-01", "2026-02-28"]);
});
Deno.test("malformed month is rejected rather than falling back to rolling range", () => {
  for (
    const month of [
      null,
      123,
      "2026-13-01",
      "2026-02-02",
      "2026-2-01",
      "2026-02-01T00:00:00Z",
      "0000-01-01",
    ]
  ) {
    let rejected = false;
    try {
      advisorPeriod({ month }, "2026-10-28");
    } catch (_) {
      rejected = true;
    }
    equal(rejected, true);
  }
});
Deno.test("existing rolling ranges retain their periods", () => {
  const p = advisorPeriod({ range: 30 }, "2026-10-28");
  equal([p.isMonthly, p.from, p.to, p.prevFrom, p.prevTo], [
    false,
    "2026-09-29",
    "2026-10-28",
    "2026-08-30",
    "2026-09-28",
  ]);
});
