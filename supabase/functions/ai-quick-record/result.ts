import { HttpError } from "../_shared/http.ts";
import { deaccent, formatVnd, normalizeAmount } from "../_shared/money.ts";

export type TxType = "income" | "expense";
export interface Category {
  id: string;
  name: string;
  type: TxType;
}
export interface Wallet {
  id: string;
  name: string;
  type: string;
}

export interface AiDraft {
  source_text?: string;
  missing_fields?: string[];
  is_transaction: boolean;
  type: TxType;
  amount: number;
  category: string;
  wallet?: string | null;
  note: string;
  date: string;
  merchant?: string | null;
  confidence: number;
  question?: string | null;
}

const sameName = (a: string, b: string) =>
  deaccent(a.trim().toLowerCase()) === deaccent(b.trim().toLowerCase());

function buildResult(
  ai: AiDraft,
  ctx: {
    categories: Category[];
    wallets: Wallet[];
    text: string;
    today: string;
    source: string;
  },
) {
  const warnings: string[] = [];
  const confidence = Math.min(1, Math.max(0, Number(ai.confidence) || 0));
  const rawAmount = Math.round(Number(ai.amount));
  const sourceText = ai.source_text || ctx.text;
  const explicitUnit =
    /(?:\d\s*(?:k|nghìn|ngàn|tr|triệu|củ|đồng|vnd|₫)|\bVND\b)/iu;
  const bareNumber = sourceText.match(/\d+(?:[.,]\d+)*/g);
  const ambiguousBare = ctx.source !== "receipt" && bareNumber?.length === 1 &&
    Number(bareNumber[0].replace(",", ".")) < 1000 &&
    !explicitUnit.test(sourceText) && !explicitUnit.test(ctx.text);
  const amount = !ambiguousBare && !ai.missing_fields?.includes("amount") &&
      Number.isFinite(rawAmount) && rawAmount > 0
    ? rawAmount
    : 0;

  if (!ai.is_transaction) {
    return {
      draft: null,
      confidence,
      question: ai.question ||
        "Bạn nói rõ giúp mình số tiền và nội dung giao dịch nhé?",
      warnings,
    };
  }

  const type: TxType = ai.type === "income" ? "income" : "expense";
  const sameType = ctx.categories.filter((c) => c.type === type);
  const category = sameType.find((c) => sameName(c.name, ai.category ?? "")) ??
    sameType.find((c) => deaccent(c.name.toLowerCase()).includes("khac")) ??
    null;
  if (!category) warnings.push("CATEGORY_NOT_FOUND");

  const wallet =
    (ai.wallet
      ? ctx.wallets.find((w) => sameName(w.name, ai.wallet!))
      : undefined) ??
      ctx.wallets[0] ?? null;

  let date = ctx.today;
  if (/^\d{4}-\d{2}-\d{2}$/.test(ai.date ?? "") && ai.date <= ctx.today) {
    date = ai.date;
  } else warnings.push("DATE_ADJUSTED");

  // Đối chiếu với bộ chuẩn hoá cục bộ: lệch > 1% thì hỏi lại user (mục 3.8 tài liệu)
  const localAmount = ctx.text ? normalizeAmount(ctx.text) : null;
  let question = ai.question ||
    (amount === 0 ? "Khoản này bao nhiêu tiền và dùng đơn vị nào?" : null);
  if (
    amount > 0 && localAmount !== null &&
    Math.abs(localAmount - amount) > localAmount * 0.01
  ) {
    warnings.push("AMOUNT_MISMATCH");
    question = `Bạn muốn ghi ${formatVnd(amount)} hay ${
      formatVnd(localAmount)
    }?`;
  }

  return {
    draft: {
      type,
      amount,
      category_id: category?.id ?? null,
      category_name: category?.name ?? null,
      wallet_id: wallet?.id ?? null,
      wallet_name: wallet?.name ?? null,
      note: (ai.note ?? "").trim().slice(0, 255) || ctx.text.slice(0, 60),
      occurred_at: date === ctx.today
        ? new Date().toISOString()
        : `${date}T12:00:00+07:00`,
      source: ctx.source,
      merchant: ai.merchant || null,
    },
    confidence,
    question,
    local_amount: localAmount,
    warnings,
  };
}

export function buildMultiResult(
  drafts: AiDraft[],
  ctx: Parameters<typeof buildResult>[1],
) {
  if (!Array.isArray(drafts)) {
    throw new HttpError(
      502,
      "INVALID_AI_RESPONSE",
      "AI chưa trả về giao dịch hợp lệ",
    );
  }
  const results = drafts.slice(0, 10).map((draft) =>
    buildResult(draft, { ...ctx, text: drafts.length === 1 ? ctx.text : "" })
  );
  const items = results.map((result, index) => ({
    draft: result.draft,
    source_text: drafts[index].source_text ||
      (drafts.length === 1 ? ctx.text : drafts[index].note || ""),
    question: result.question,
    missing_fields: [
      ...new Set([
        ...(drafts[index].missing_fields || []),
        ...(result.draft?.amount === 0 ? ["amount"] : []),
      ]),
    ],
  }));
  const valid = results.flatMap((result) => result.draft ? [result.draft] : []);
  return {
    items,
    draft: valid[0] ?? null,
    drafts: valid,
    question: results.map((r) => r.question).filter(Boolean).join("\n") || null,
    warnings: [...new Set(results.flatMap((r) => r.warnings))],
  };
}
