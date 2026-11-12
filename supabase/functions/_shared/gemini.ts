import { HttpError } from "./http.ts";

// Structured output still needs semantic validation at each caller.
// Retry once within 27s. Never log upstream bodies or receipt/user content.
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

interface Dependencies {
  fetch?: typeof fetch;
  apiKey?: string;
  delay?: (ms: number) => Promise<void>;
}

export async function generateJson<T>(options: {
  system: string;
  contents: GeminiContent[];
  schema: Record<string, unknown>;
  temperature?: number;
}, dependencies: Dependencies = {}): Promise<T> {
  const apiKey = dependencies.apiKey ?? Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    throw new HttpError(
      500,
      "AI_NOT_CONFIGURED",
      "AI chưa được cấu hình trên server",
    );
  }
  const model = Deno.env.get("GEMINI_MODEL") || DEFAULT_MODEL;

  const request = dependencies.fetch ?? fetch;
  const delay = dependencies.delay ??
    ((ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms)));
  const deadline = Date.now() + 27_000;
  const payload = JSON.stringify({
    systemInstruction: { parts: [{ text: options.system }] },
    contents: options.contents,
    generationConfig: {
      temperature: options.temperature ?? 0.2,
      responseMimeType: "application/json",
      responseSchema: options.schema,
    },
  });
  let body;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const response = await request(`${API_BASE}/${model}:generateContent`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: payload,
        signal: AbortSignal.timeout(
          Math.max(1, Math.min(12_000, deadline - Date.now())),
        ),
      });
      if (response.ok) {
        try {
          body = await response.json();
        } catch (error) {
          if (error instanceof SyntaxError) {
            throw new HttpError(
              502,
              "AI_INVALID_RESPONSE",
              "AI trả về dữ liệu không hợp lệ, vui lòng thử lại",
            );
          }
          throw error;
        }
        break;
      }
      const retryAfter = Number(response.headers.get("retry-after") ?? 0);
      const transient = [429, 500, 502, 503, 504].includes(response.status);
      await response.body?.cancel();
      if (
        attempt === 0 && transient && retryAfter <= 1 &&
        Date.now() + 13_000 < deadline
      ) {
        await delay(
          Math.max(retryAfter * 1000, 500 + Math.floor(Math.random() * 300)),
        );
        continue;
      }
      if ([429, 503].includes(response.status)) {
        throw new HttpError(
          503,
          "AI_BUSY",
          "AI đang quá tải, vui lòng thử lại sau ít phút",
        );
      }
      throw new HttpError(
        502,
        "AI_UPSTREAM_ERROR",
        "AI tạm thời không phản hồi, vui lòng thử lại",
      );
    } catch (error) {
      if (error instanceof HttpError) throw error;
      if (attempt === 0 && Date.now() + 13_000 < deadline) {
        await delay(500);
        continue;
      }
      throw new HttpError(
        504,
        "AI_TIMEOUT",
        "AI phản hồi quá lâu, vui lòng thử lại",
      );
    }
  }
  const text: string = (body?.candidates?.[0]?.content?.parts ?? [])
    .filter((p: { thought?: boolean }) => !p.thought)
    .map((p: { text?: string }) => p.text ?? "")
    .join("");
  if (!text) {
    throw new HttpError(
      502,
      "AI_EMPTY_RESPONSE",
      "AI không trả về kết quả, hãy thử diễn đạt rõ hơn",
    );
  }

  try {
    const value = JSON.parse(text);
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      throw new Error();
    }
    return value as T;
  } catch {
    throw new HttpError(
      502,
      "AI_INVALID_RESPONSE",
      "AI trả về dữ liệu không hợp lệ, vui lòng thử lại",
    );
  }
}
