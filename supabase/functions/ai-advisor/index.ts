// POST /functions/v1/ai-advisor
// AI Financial Advisor (mục 8.1 tài liệu): phân tích chi tiêu 30/90 ngày, so sánh với kỳ trước, dự đoán tháng tới.
// Số liệu (tổng, % thay đổi, baseline dự đoán) do server tính; Gemini chỉ viết nhận xét và lời khuyên.
//
// Body: { "range": 30 | 90 }   (mặc định 30)
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { readJson, serve } from "../_shared/http.ts";
import { consumeAiQuota, getUserClient, vnToday } from "../_shared/supabase.ts";
import { generateJson } from "../_shared/gemini.ts";

interface CategoryTotal {
  type: "income" | "expense";
  category_id: string | null;
  name: string | null;
  total: number;
  count: number;
}

interface PeriodSummary {
  from: string;
  to: string;
  income: number;
  expense: number;
  transaction_count: number;
  by_category: CategoryTotal[];
}

interface AiAdvice {
  summary: string;
  insights: { category: string; advice: string }[];
  forecast: { nextMonth: number; riskCategories: string[] };
}

const ADVICE_SCHEMA = {
  type: "OBJECT",
  properties: {
    summary: { type: "STRING" },
    insights: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: { category: { type: "STRING" }, advice: { type: "STRING" } },
        required: ["category", "advice"],
      },
    },
    forecast: {
      type: "OBJECT",
      properties: {
        nextMonth: { type: "INTEGER" },
        riskCategories: { type: "ARRAY", items: { type: "STRING" } },
      },
      required: ["nextMonth", "riskCategories"],
    },
  },
  required: ["summary", "insights", "forecast"],
};

const SYSTEM_PROMPT = `Bạn là cố vấn tài chính cá nhân của app Túi Khôn.
Bạn nhận số liệu chi tiêu đã được tính sẵn (VND) của kỳ này và kỳ trước. KHÔNG tự tính lại hay bịa số liệu.
Trả về JSON:
- summary: nhận xét tổng quan 1-2 câu
- insights: tối đa 4 mục {category, advice}, ưu tiên danh mục tăng mạnh hoặc chiếm tỷ trọng lớn; category chép y nguyên tên trong dữ liệu; advice cụ thể, có con số gợi ý (vd "Nên giảm khoảng 500k")
- forecast.nextMonth: dự đoán tổng chi 30 ngày tới (VND), tham khảo baseline_next_month
- forecast.riskCategories: tối đa 3 danh mục dễ vượt chi
Ngôn ngữ: tiếng Việt, thân thiện, ngắn gọn.`;

serve(async (req) => {
  const { supabase } = await getUserClient(req);
  const body = await readJson(req);
  const range = body.range === 90 ? 90 : 30;

  const to = vnToday();
  const from = addDays(to, -(range - 1));
  const prevTo = addDays(from, -1);
  const prevFrom = addDays(prevTo, -(range - 1));

  const [curRes, prevRes] = await Promise.all([
    supabase.rpc("get_period_summary", { p_from: from, p_to: to }),
    supabase.rpc("get_period_summary", { p_from: prevFrom, p_to: prevTo }),
  ]);
  if (curRes.error) throw curRes.error;
  if (prevRes.error) throw prevRes.error;
  const cur = curRes.data as PeriodSummary;
  const prev = prevRes.data as PeriodSummary;

  const totals = {
    income: cur.income,
    expense: cur.expense,
    previousIncome: prev.income,
    previousExpense: prev.expense,
    expenseChange: percentChange(cur.expense, prev.expense),
  };
  const period = { from, to, range };

  if (cur.expense === 0) {
    return {
      period,
      totals,
      summary: `Chưa có khoản chi nào trong ${range} ngày qua. Hãy ghi chép thêm để Túi Khôn phân tích giúp bạn nhé!`,
      insights: [],
      forecast: { nextMonth: 0, riskCategories: [], baseline: 0 },
    };
  }

  const previousByCategory = new Map(
    prev.by_category.filter((c) => c.type === "expense").map((c) => [c.category_id, c.total]),
  );
  const categories = cur.by_category
    .filter((c) => c.type === "expense")
    .slice(0, 8)
    .map((c) => {
      const previous = previousByCategory.get(c.category_id) ?? 0;
      return {
        category: c.name ?? "Chưa phân loại",
        total: c.total,
        previous,
        change: percentChange(c.total, previous),
        share: Math.round((c.total / cur.expense) * 100),
      };
    });
  const baseline = Math.round((cur.expense / range) * 30);

  const quota = await consumeAiQuota(supabase, "advisor");

  const ai = await generateJson<AiAdvice>({
    system: SYSTEM_PROMPT,
    contents: [{
      role: "user",
      parts: [{
        text: JSON.stringify({
          period_days: range,
          current: { income: cur.income, expense: cur.expense },
          previous: { income: prev.income, expense: prev.expense },
          expense_change_percent: totals.expenseChange,
          categories,
          baseline_next_month: baseline,
        }),
      }],
    }],
    schema: ADVICE_SCHEMA,
    temperature: 0.4,
  });

  // Ghép lời khuyên của AI vào số liệu thật; bỏ những danh mục AI tự nghĩ ra
  const insights = (ai.insights ?? [])
    .map((i) => {
      const data = categories.find((c) => c.category === i.category);
      return data ? { category: data.category, total: data.total, change: data.change, advice: i.advice } : null;
    })
    .filter((i) => i !== null)
    .slice(0, 4);

  const aiForecast = Math.round(Number(ai.forecast?.nextMonth));
  const nextMonth = aiForecast > 0 && aiForecast <= baseline * 3 && aiForecast >= baseline / 3 ? aiForecast : baseline;
  const knownNames = new Set(categories.map((c) => c.category));

  return {
    period,
    totals,
    summary: ai.summary,
    insights,
    forecast: {
      nextMonth,
      baseline,
      riskCategories: (ai.forecast?.riskCategories ?? []).filter((n) => knownNames.has(n)).slice(0, 3),
    },
    quota: { used: quota.used, limit: quota.limit },
  };
});

function addDays(isoDate: string, days: number): string {
  const d = new Date(`${isoDate}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

// null khi kỳ trước = 0 (không so sánh được)
function percentChange(current: number, previous: number): number | null {
  return previous > 0 ? Math.round(((current - previous) / previous) * 100) : null;
}
