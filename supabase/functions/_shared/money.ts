// Chuẩn hoá số tiền tiếng Việt (mục 3.2–3.5 tài liệu phát triển).
// Dùng để đối chiếu với số tiền Gemini trả về; trường hợp mơ hồ ("hai trăm", "phở 65") để Gemini xử lý.

const UNIT: Record<string, number> = {
  k: 1e3, nghin: 1e3, ngan: 1e3, ngin: 1e3,
  tr: 1e6, trieu: 1e6, cu: 1e6,
  ty: 1e9, ti: 1e9, toi: 1e9,
};

// <số> <đơn vị> [chữ số lẻ, vd 1tr5] [rưỡi]; đơn vị không được dính chữ phía sau ("2 trà", "300 cuốn")
const UNIT_RE = /(\d+(?:[.,]\d+)*)\s*(nghin|ngan|ngin|trieu|tr|cu|toi|ty|ti|k)(\d)?(?![a-z0-9])(\s+ruoi)?/g;
// <số> đ/đồng/vnd, vd "65.000đ", "120000 dong"
const CURRENCY_RE = /(\d{1,3}(?:[.,]\d{3})+|\d+)\s*(?:d|dong|vnd)(?![a-z])/g;

export function deaccent(s: string): string {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/g, "d").replace(/Đ/g, "D");
}

// "1.500" / "1,500" (phân tách hàng nghìn) → 1500; "1,5" / "2.5" (thập phân) → 1.5 / 2.5
function parseNumber(raw: string): number {
  if (/^\d{1,3}([.,]\d{3})+$/.test(raw)) return Number(raw.replace(/[.,]/g, ""));
  return Number(raw.replace(",", "."));
}

export function normalizeAmount(input: string): number | null {
  const text = deaccent(input.toLowerCase());
  const candidates: number[] = [];

  for (const m of text.matchAll(UNIT_RE)) {
    let base = parseNumber(m[1]);
    if (m[3]) base += Number(m[3]) / 10;
    if (m[4]) base += 0.5;
    candidates.push(base * UNIT[m[2]]);
  }
  for (const m of text.matchAll(CURRENCY_RE)) {
    candidates.push(parseNumber(m[1]));
  }

  const valid = candidates.filter((v) => Number.isFinite(v) && v > 0);
  return valid.length ? Math.round(Math.max(...valid)) : null; // chọn ứng viên lớn nhất
}

export function formatVnd(amount: number): string {
  return `${Math.round(amount).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".")}đ`;
}
