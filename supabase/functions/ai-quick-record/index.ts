// POST /functions/v1/ai-quick-record
// Ghi chép bằng lời nói / chữ / ảnh hóa đơn → trả về BẢN NHÁP giao dịch để app hiện action card.
// Function KHÔNG ghi DB: user bấm "Lưu" thì app tự insert vào bảng transactions.
//
// Body:
//   { "text": "ăn phở 65k", "source": "voice" | "text",
//     "history": [{ "role": "user" | "model", "text": "..." }] }   // tuỳ chọn, khi AI hỏi lại
//   { "imageBase64": "...", "mimeType": "image/jpeg", "text": "ghi chú thêm (tuỳ chọn)" }
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { HttpError, readJson, serve } from "../_shared/http.ts";
import { consumeAiQuota, getUserClient, vnToday } from "../_shared/supabase.ts";
import {
  type GeminiContent,
  type GeminiPart,
  generateJson,
} from "../_shared/gemini.ts";
import {
  type AiDraft,
  buildMultiResult,
  type Category,
  type TxType,
  type Wallet,
} from "./result.ts";

const MAX_TEXT_LENGTH = 500;
const MAX_IMAGE_BASE64_LENGTH = 7_000_000; // ~5MB ảnh gốc
const IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp", "image/heic"];
const MAX_HISTORY = 6;

const DRAFT_SCHEMA = {
  type: "OBJECT",
  properties: {
    source_text: {
      type: "STRING",
      description: "Đoạn nguyên văn chỉ của giao dịch này",
    },
    missing_fields: { type: "ARRAY", items: { type: "STRING" } },
    is_transaction: { type: "BOOLEAN" },
    type: { type: "STRING", enum: ["income", "expense"] },
    amount: {
      type: "INTEGER",
      description: "Số tiền VND, số nguyên, đã quy đổi đơn vị",
    },
    category: {
      type: "STRING",
      description: "Tên danh mục, chép y nguyên từ danh sách",
    },
    wallet: { type: "STRING", nullable: true },
    note: { type: "STRING" },
    date: { type: "STRING", description: "YYYY-MM-DD" },
    merchant: { type: "STRING", nullable: true },
    confidence: { type: "NUMBER" },
    question: { type: "STRING", nullable: true },
  },
  required: [
    "source_text",
    "missing_fields",
    "is_transaction",
    "type",
    "amount",
    "category",
    "note",
    "date",
    "confidence",
  ],
  propertyOrdering: [
    "source_text",
    "missing_fields",
    "is_transaction",
    "type",
    "amount",
    "category",
    "wallet",
    "note",
    "date",
    "merchant",
    "confidence",
    "question",
  ],
};

serve(async (req) => {
  const { supabase } = await getUserClient(req);
  const body = await readJson(req);

  const text = typeof body.text === "string" ? body.text.trim() : "";
  const image = typeof body.imageBase64 === "string"
    ? body.imageBase64.replace(/^data:[^,]*,/, "")
    : "";
  const mimeType = typeof body.mimeType === "string"
    ? body.mimeType
    : "image/jpeg";

  if (!text && !image) {
    throw new HttpError(
      400,
      "VALIDATION_ERROR",
      "Hãy nhập nội dung hoặc chụp ảnh hóa đơn",
    );
  }
  if (text.length > MAX_TEXT_LENGTH) {
    throw new HttpError(
      400,
      "VALIDATION_ERROR",
      `Nội dung tối đa ${MAX_TEXT_LENGTH} ký tự`,
    );
  }
  if (image && image.length > MAX_IMAGE_BASE64_LENGTH) {
    throw new HttpError(
      413,
      "IMAGE_TOO_LARGE",
      "Ảnh quá lớn, hãy resize ≤1920px trước khi gửi",
    );
  }
  if (image && !IMAGE_TYPES.includes(mimeType)) {
    throw new HttpError(400, "VALIDATION_ERROR", "Định dạng ảnh không hỗ trợ");
  }

  const [categoriesRes, walletsRes] = await Promise.all([
    supabase.from("categories").select("id, name, type").order("name"),
    supabase.from("wallets").select("id, name, type").eq("is_archived", false)
      .order("created_at"),
  ]);
  if (categoriesRes.error) throw categoriesRes.error;
  if (walletsRes.error) throw walletsRes.error;
  const categories = categoriesRes.data as Category[];
  const wallets = walletsRes.data as Wallet[];

  const quota = await consumeAiQuota(supabase, image ? "scan" : "chat");

  const parts: GeminiPart[] = [];
  if (image) parts.push({ inlineData: { mimeType, data: image } });
  if (text) parts.push({ text });

  const today = vnToday();
  const ai = await generateJson<{ drafts: AiDraft[] }>({
    system: buildSystemPrompt(categories, wallets, today),
    contents: [...parseHistory(body.history), { role: "user", parts }],
    schema: {
      type: "OBJECT",
      properties: {
        drafts: { type: "ARRAY", items: DRAFT_SCHEMA, maxItems: 10 },
      },
      required: ["drafts"],
    },
  });

  const source = image ? "receipt" : body.source === "voice" ? "voice" : "ai";
  return {
    ...buildMultiResult(ai.drafts, {
      categories,
      wallets,
      text: image ? "" : text,
      today,
      source,
    }),
    quota: { used: quota.used, limit: quota.limit },
  };
});

function buildSystemPrompt(
  categories: Category[],
  wallets: Wallet[],
  today: string,
): string {
  const names = (type: TxType) =>
    categories.filter((c) => c.type === type).map((c) => c.name).join(", ");
  return `Bạn là trợ lý tài chính của app Túi Khôn. Hôm nay là ${today} (giờ Việt Nam).
Nhiệm vụ: từ câu tiếng Việt hoặc ảnh hóa đơn của người dùng, trích xuất tối đa 10 giao dịch độc lập, theo thứ tự, vào mảng drafts. Không gộp số tiền của các giao dịch. Nếu thiếu thông tin, trả một phần tử có question.

Quy tắc:
- amount: số nguyên VND đã quy đổi. k/nghìn/ngàn = 1.000; tr/triệu/củ = 1.000.000; tỷ/tỏi = 1.000.000.000; "rưỡi" = cộng nửa đơn vị đứng trước; "1tr5" = 1.500.000; "xị" = 100.000; "chục" = 10 (vd "năm chục k" = 50.000). Không tự đoán đơn vị cho số trần mơ hồ ("phở 65"): amount = 0, missing_fields = ["amount"], hỏi lại 65 đồng hay 65 nghìn.
- type: "income" khi là tiền vào (lương, thưởng, trúng số, được cho, thu nợ, bán đồ); còn lại là "expense". Cho người khác mượn tiền là "expense".
- category: chọn ĐÚNG MỘT tên trong danh sách cùng loại với type, chép y nguyên. Không chắc thì chọn danh mục "khác" của loại đó.
- wallet: tên ví trong danh sách nếu người dùng nhắc tới (MoMo, Vietcombank, tiền mặt...), nếu không thì null.
- date: YYYY-MM-DD; "hôm qua" là ngày trước hôm nay; mặc định là hôm nay.
- note: mô tả ngắn ≤ 60 ký tự, viết hoa chữ cái đầu, không ghi lại số tiền.
- Ảnh hóa đơn: amount = TỔNG THANH TOÁN cuối cùng; merchant = tên cửa hàng; date = ngày in trên hóa đơn; ảnh mờ hoặc không phải hóa đơn thì confidence thấp.
- Giao dịch thiếu hoặc mơ hồ số tiền vẫn is_transaction = true, amount = 0, missing_fields chứa "amount", question hỏi riêng cho giao dịch đó. Giữ mọi giao dịch độc lập, không bỏ giao dịch thiếu thông tin.
- Chỉ khi không phải giao dịch mới is_transaction = false.
- source_text: nguyên văn phần câu mô tả riêng giao dịch; missing_fields: các trường còn thiếu; question: câu hỏi riêng từng giao dịch, null khi đủ dữ liệu.
- Khi history là ngữ cảnh một giao dịch đang hỏi bổ sung, chỉ trả giao dịch đó đã cập nhật, không lặp lại giao dịch khác.
- confidence: từ 0 đến 1.

Danh mục chi: ${names("expense")}
Danh mục thu: ${names("income")}
Ví: ${wallets.map((w) => w.name).join(", ")}

Ví dụ:
"Tôi trúng số 300 củ" → income, 300000000, Thu nhập khác
"Ăn phở 65k" → expense, 65000, Ăn uống
"Đổ xăng 80 nghìn" → expense, 80000, Di chuyển
"Lương tháng này 15 triệu" → income, 15000000, Lương
"Cho Lan mượn 2 tr" → expense, 2000000, Cho vay & Trả nợ
"Lương về 1 tỏi rưỡi" → income, 1500000000, Lương`;
}

function parseHistory(raw: unknown): GeminiContent[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((m) =>
      m && (m.role === "user" || m.role === "model") &&
      typeof m.text === "string" && m.text.trim()
    )
    .slice(-MAX_HISTORY)
    .map((m) => ({
      role: m.role,
      parts: [{ text: String(m.text).slice(0, MAX_TEXT_LENGTH) }],
    }));
}
