import { HttpError } from "./http.ts";

// Gọi Gemini với structured output (responseSchema) → luôn nhận JSON hợp lệ, không cần regex.
// Model đổi được qua secret GEMINI_MODEL mà không phải sửa code.

const API_BASE = "https://generativelanguage.googleapis.com/v1beta/models";
const DEFAULT_MODEL = "gemini-flash-latest";

export type GeminiPart =
  | { text: string }
  | { inlineData: { mimeType: string; data: string } };

export interface GeminiContent {
  role: "user" | "model";
  parts: GeminiPart[];
}

export async function generateJson<T>(options: {
  system: string;
  contents: GeminiContent[];
  schema: Record<string, unknown>;
  temperature?: number;
}): Promise<T> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) throw new HttpError(500, "AI_NOT_CONFIGURED", "AI chưa được cấu hình trên server");
  const model = Deno.env.get("GEMINI_MODEL") || DEFAULT_MODEL;

  let res: Response;
  try {
    res = await fetch(`${API_BASE}/${model}:generateContent`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: options.system }] },
        contents: options.contents,
        generationConfig: {
          temperature: options.temperature ?? 0.2,
          responseMimeType: "application/json",
          responseSchema: options.schema,
        },
      }),
      signal: AbortSignal.timeout(30_000),
    });
  } catch (error) {
    console.error("Gemini request failed", error);
    throw new HttpError(504, "AI_TIMEOUT", "AI phản hồi quá lâu, vui lòng thử lại");
  }

  if (!res.ok) {
    console.error("Gemini error", res.status, await res.text());
    if (res.status === 429) throw new HttpError(503, "AI_BUSY", "AI đang quá tải, vui lòng thử lại sau ít phút");
    throw new HttpError(502, "AI_UPSTREAM_ERROR", "AI tạm thời không phản hồi, vui lòng thử lại");
  }

  const body = await res.json();
  const text: string = (body?.candidates?.[0]?.content?.parts ?? [])
    .map((p: { text?: string }) => p.text ?? "")
    .join("");
  if (!text) {
    console.error("Gemini empty response", JSON.stringify(body));
    throw new HttpError(502, "AI_EMPTY_RESPONSE", "AI không trả về kết quả, hãy thử diễn đạt rõ hơn");
  }

  try {
    return JSON.parse(text) as T;
  } catch {
    console.error("Gemini returned invalid JSON", text);
    throw new HttpError(502, "AI_INVALID_RESPONSE", "AI trả về dữ liệu không hợp lệ, vui lòng thử lại");
  }
}
