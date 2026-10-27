import { HttpError } from "../_shared/http.ts";

export function advisorPeriod(body: Record<string, unknown>, today: string) {
  const month = body.month;
  if (
    month !== undefined && (typeof month !== "string" ||
      !/^\d{4}-(0[1-9]|1[0-2])-01$/.test(month) || month < "1900-01-01" ||
      month > "9998-12-01")
  ) {
    throw new HttpError(
      400,
      "VALIDATION_ERROR",
      "month phải có dạng YYYY-MM-01",
    );
  }
  const isMonthly = typeof month === "string";
  const to = isMonthly ? addDays(followingMonth(month), -1) : today;
  const range = isMonthly
    ? Number(to.slice(8, 10))
    : body.range === 90
    ? 90
    : 30;
  const from = isMonthly ? month : addDays(to, -(range - 1));
  const prevTo = addDays(from, -1);
  const prevFrom = isMonthly
    ? `${prevTo.slice(0, 7)}-01`
    : addDays(prevTo, -(range - 1));
  return {
    month: isMonthly ? month : undefined,
    isMonthly,
    from,
    to,
    range,
    prevFrom,
    prevTo,
  };
}

function followingMonth(month: string): string {
  const d = new Date(`${month}T00:00:00Z`);
  d.setUTCMonth(d.getUTCMonth() + 1);
  return d.toISOString().slice(0, 10);
}

function addDays(isoDate: string, days: number): string {
  const d = new Date(`${isoDate}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}
