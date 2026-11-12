import { HttpError } from "../_shared/http.ts";
export const KINDS = [
  "summary",
  "comparison",
  "ranking",
  "transactions",
  "balances",
  "budgets",
  "debts",
  "payables",
  "goals",
] as const;
export interface QueryPlan {
  kind: string;
  from: string;
  to: string;
  type?: string | null;
  category_id?: string | null;
  wallet_id?: string | null;
  search?: string;
  debt_type?: string | null;
  overdue_only?: boolean;
  period_filter?: boolean;
}
export function validatePlan(
  raw: unknown,
  categories: { id: string }[],
  wallets: { id: string }[],
): QueryPlan {
  const p = raw as QueryPlan;
  const validDate = (date: unknown): date is string => {
    if (typeof date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return false;
    }
    const parsed = new Date(`${date}T00:00:00Z`);
    return !isNaN(parsed.getTime()) &&
      parsed.toISOString().slice(0, 10) === date && date >= "2000-01-01" &&
      date <= "2200-01-01";
  };
  if (
    !p || typeof p !== "object" ||
    !KINDS.includes(p.kind as typeof KINDS[number]) || !validDate(p.from) ||
    !validDate(p.to) ||
    p.from >= p.to ||
    (Date.parse(p.to) - Date.parse(p.from)) / 86400000 > 3660 ||
    ![undefined, null, "income", "expense"].includes(p.type) ||
    ![undefined, null, "borrow", "lend"].includes(p.debt_type) ||
    (p.category_id != null &&
      !categories.some((c) => c.id === p.category_id)) ||
    (p.wallet_id != null && !wallets.some((w) => w.id === p.wallet_id)) ||
    (p.search !== undefined &&
      (typeof p.search !== "string" || p.search.length > 100)) ||
    (p.overdue_only !== undefined && typeof p.overdue_only !== "boolean") ||
    (p.period_filter !== undefined && typeof p.period_filter !== "boolean")
  ) {
    throw new HttpError(
      502,
      "AI_INVALID_RESPONSE",
      "Chưa xác định được bộ lọc hợp lệ",
    );
  }
  return {
    kind: p.kind,
    from: p.from,
    to: p.to,
    type: p.type ?? null,
    category_id: p.category_id ?? null,
    wallet_id: p.wallet_id ?? null,
    search: p.search ?? "",
    debt_type: p.debt_type ?? null,
    overdue_only: p.overdue_only ?? false,
    period_filter: p.period_filter ?? false,
  };
}
