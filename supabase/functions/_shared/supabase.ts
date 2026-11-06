import { createClient, type SupabaseClient, type User } from "npm:@supabase/supabase-js@2";
import { HttpError } from "./http.ts";

// Client chạy dưới quyền của chính user gọi function → mọi truy vấn vẫn đi qua RLS.
export async function getUserClient(req: Request): Promise<{ supabase: SupabaseClient; user: User }> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    throw new HttpError(401, "UNAUTHORIZED", "Bạn cần đăng nhập để dùng tính năng này");
  }

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await supabase.auth.getUser(authHeader.slice("Bearer ".length));
  if (error || !data.user) {
    throw new HttpError(401, "UNAUTHORIZED", "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại");
  }
  return { supabase, user: data.user };
}

export type AiKind = "chat" | "scan" | "advisor";

// Trừ 1 lượt AI trong ngày (giờ VN). Hết lượt → 429 kèm số giây đến 0h hôm sau.
export async function consumeAiQuota(supabase: SupabaseClient, kind: AiKind) {
  const { data, error } = await supabase.rpc("consume_ai_quota", { p_kind: kind });
  if (error) throw error;

  const quota = data as { allowed: boolean; used: number; limit: number };
  if (!quota.allowed) {
    const messages: Record<AiKind, string> = {
      chat: `Bạn đã dùng hết ${quota.limit} lượt AI Chat hôm nay`,
      scan: `Bạn đã vượt giới hạn quét hóa đơn hôm nay (${quota.limit} lượt)`,
      advisor: `Bạn đã dùng hết ${quota.limit} lượt phân tích AI hôm nay`,
    };
    throw new HttpError(429, "RATE_LIMIT_EXCEEDED", messages[kind], {
      limit: quota.limit,
      retryAfter: secondsUntilVnMidnight(),
    });
  }
  return quota;
}

// Ngày hiện tại theo giờ Việt Nam, dạng YYYY-MM-DD
export function vnToday(now = new Date()): string {
  return new Date(now.getTime() + 7 * 3600_000).toISOString().slice(0, 10);
}

function secondsUntilVnMidnight(now = new Date()): number {
  const vn = new Date(now.getTime() + 7 * 3600_000);
  const nextMidnightVn = Date.UTC(vn.getUTCFullYear(), vn.getUTCMonth(), vn.getUTCDate() + 1);
  return Math.ceil((nextMidnightVn - vn.getTime()) / 1000);
}
