// Định dạng response chuẩn của Túi Khôn (mục 2.2 tài liệu phát triển):
//   { "success": true,  "data": {...} }
//   { "success": false, "error": { "code", "message", "details" } }

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly details?: Record<string, unknown>,
  ) {
    super(message);
  }
}

export function ok(data: unknown, status = 200): Response {
  return new Response(JSON.stringify({ success: true, data }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function fail(error: unknown): Response {
  const e = error instanceof HttpError
    ? error
    : new HttpError(500, "INTERNAL_ERROR", "Có lỗi xảy ra, vui lòng thử lại sau");
  if (!(error instanceof HttpError)) console.error(error);
  return new Response(
    JSON.stringify({
      success: false,
      error: { code: e.code, message: e.message, details: e.details ?? {} },
    }),
    { status: e.status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
}

// Bọc handler: xử lý preflight CORS, chỉ nhận POST, chuẩn hoá lỗi
export function serve(handler: (req: Request) => Promise<unknown>) {
  Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    try {
      if (req.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Chỉ hỗ trợ POST");
      return ok(await handler(req));
    } catch (error) {
      return fail(error);
    }
  });
}

// Body rỗng được coi là {}
export async function readJson(req: Request): Promise<Record<string, unknown>> {
  const raw = await req.text();
  if (!raw.trim()) return {};
  try {
    const body = JSON.parse(raw);
    if (body && typeof body === "object" && !Array.isArray(body)) return body;
  } catch {
    // rơi xuống lỗi bên dưới
  }
  throw new HttpError(400, "VALIDATION_ERROR", "Body phải là JSON object");
}
