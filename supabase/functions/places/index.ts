// Google Places API (New) 代理
// - 金鑰只存在伺服器（GOOGLE_PLACES_API_KEY secret），前端不再持有
// - 結果快取：搜尋 7 天、店家詳細資料與照片 30 天（Google 允許最多 30 天）
// - 每日用量限制：登入帳號 300 次、未登入（以 IP 計）100 次
// 路徑：
//   POST /places/search   {query, lat?, lng?}
//   POST /places/nearby   {lat, lng, radius}
//   GET  /places/details?id=<place_id>
//   GET  /places/photo?name=<photo name>&w=<maxWidthPx>   → 302 轉到實際圖片
import { createClient } from "npm:@supabase/supabase-js@2";

const GOOGLE_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const LIMIT_USER = 300;
const LIMIT_ANON = 100;
const TTL_SEARCH_MS = 7 * 24 * 3600 * 1000;
const TTL_DETAILS_MS = 30 * 24 * 3600 * 1000;

const SEARCH_MASK = "places.id,places.displayName,places.formattedAddress,places.location,places.types," +
  "places.primaryType,places.primaryTypeDisplayName,places.photos,places.businessStatus," +
  "places.googleMapsUri,places.priceLevel";
const DETAIL_MASK = "id,displayName,formattedAddress,location,types,primaryType,primaryTypeDisplayName," +
  "photos,businessStatus,googleMapsUri,priceLevel,regularOpeningHours,nationalPhoneNumber,websiteUri";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

function json(body: unknown, status = 200, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...CORS, ...extra },
  });
}
function fail(message: string, status = 400) {
  return json({ error: { code: status, message } }, status);
}

async function subjectOf(req: Request): Promise<{ subject: string; limit: number }> {
  const auth = req.headers.get("authorization") ?? "";
  if (auth.startsWith("Bearer ") && auth.slice(7) !== ANON_KEY) {
    try {
      const client = createClient(SUPABASE_URL, ANON_KEY, {
        global: { headers: { Authorization: auth } },
        auth: { persistSession: false },
      });
      const { data } = await client.auth.getUser();
      if (data.user) return { subject: `user:${data.user.id}`, limit: LIMIT_USER };
    } catch (_) { /* 視為未登入 */ }
  }
  const ip = (req.headers.get("x-forwarded-for") ?? "unknown").split(",")[0].trim();
  return { subject: `ip:${ip}`, limit: LIMIT_ANON };
}

async function cacheGet(key: string, ttlMs: number): Promise<unknown | null> {
  const { data } = await admin.from("places_cache").select("data, fetched_at").eq("cache_key", key).maybeSingle();
  if (!data) return null;
  if (Date.now() - new Date(data.fetched_at).getTime() > ttlMs) return null;
  return data.data;
}
async function cachePut(key: string, value: unknown) {
  await admin.from("places_cache").upsert({ cache_key: key, data: value, fetched_at: new Date().toISOString() });
}

async function google(path: string, init: RequestInit, mask: string) {
  const res = await fetch(`https://places.googleapis.com/v1/${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": GOOGLE_KEY,
      "X-Goog-FieldMask": mask,
      ...(init.headers ?? {}),
    },
  });
  const body = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, body };
}

// 只留餐飲業（與前端 isFoodPlace 相同規則）
const FOOD = new Set(["restaurant","cafe","coffee_shop","bakery","bar","pub","wine_bar","meal_takeaway","meal_delivery",
  "food_court","ice_cream_shop","dessert_shop","tea_house","juice_shop","sandwich_shop","steak_house","diner","noodle_shop",
  "food","bar_and_grill","cafeteria","food_store","confectionery","donut_shop","bagel_shop","acai_shop","chocolate_shop","candy_store"]);
function isFood(p: { types?: string[]; primaryType?: string }) {
  const ok = (t: string) => FOOD.has(t) || t.endsWith("_restaurant");
  return (p.primaryType && ok(p.primaryType)) || (p.types ?? []).some(ok);
}
function filterFood(body: { places?: Array<{ types?: string[]; primaryType?: string }> }) {
  return { places: (body.places ?? []).filter(isFood) };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (!GOOGLE_KEY) return fail("伺服器尚未設定 Google 金鑰", 500);

  const url = new URL(req.url);
  const sub = url.pathname.split("/").filter(Boolean).pop() ?? "";

  // 照片：先查快取，沒有再向 Google 要實際圖片網址，回 302
  if (sub === "photo" && req.method === "GET") {
    const name = url.searchParams.get("name") ?? "";
    const w = Math.min(1600, Math.max(100, Number(url.searchParams.get("w") ?? "800")));
    if (!name.startsWith("places/")) return fail("bad photo name");
    const key = `photo:${name}:${w}`;
    let uri = (await cacheGet(key, TTL_DETAILS_MS)) as string | null;
    if (!uri) {
      const { subject, limit } = await subjectOf(req);
      const { data: allowed } = await admin.rpc("bump_usage", { p_subject: subject, p_limit: limit });
      if (allowed === false) return fail("今日查詢次數已達上限，明天再試", 429);
      const res = await fetch(`https://places.googleapis.com/v1/${name}/media?maxWidthPx=${w}&skipHttpRedirect=true&key=${GOOGLE_KEY}`);
      const body = await res.json().catch(() => ({}));
      uri = body.photoUri;
      if (!uri) return fail("取得照片失敗", 502);
      await cachePut(key, uri);
    }
    return new Response(null, { status: 302, headers: { Location: uri, "Cache-Control": "public, max-age=86400", ...CORS } });
  }

  // 其餘：搜尋、附近、詳細資料
  let key = "";
  let ttl = TTL_SEARCH_MS;
  let run: () => Promise<{ ok: boolean; status: number; body: unknown }>;

  if (sub === "search" && req.method === "POST") {
    const { query, lat, lng } = await req.json().catch(() => ({}));
    const q = String(query ?? "").trim();
    if (!q) return fail("缺少 query");
    const near = (typeof lat === "number" && typeof lng === "number") ? `${lat.toFixed(2)}:${lng.toFixed(2)}` : "tw";
    key = `search:${q.toLowerCase()}:${near}`;
    run = async () => {
      const r = await google("places:searchText", {
        method: "POST",
        body: JSON.stringify({
          textQuery: q, includedType: "restaurant", regionCode: "TW", languageCode: "zh-TW", pageSize: 20,
          locationBias: near === "tw"
            ? { rectangle: { low: { latitude: 21.8, longitude: 118.2 }, high: { latitude: 26.4, longitude: 122.1 } } }
            : { circle: { center: { latitude: lat, longitude: lng }, radius: 5000.0 } },
        }),
      }, SEARCH_MASK);
      return r.ok ? { ...r, body: filterFood(r.body as { places?: [] }) } : r;
    };
  } else if (sub === "nearby" && req.method === "POST") {
    const { lat, lng, radius } = await req.json().catch(() => ({}));
    if (typeof lat !== "number" || typeof lng !== "number") return fail("缺少座標");
    const r = Math.min(3000, Math.max(100, Number(radius ?? 1000)));
    key = `nearby:${lat.toFixed(3)}:${lng.toFixed(3)}:${Math.round(r / 100)}`;
    run = async () => {
      const res = await google("places:searchNearby", {
        method: "POST",
        body: JSON.stringify({
          includedTypes: ["restaurant","cafe","bakery","bar","meal_takeaway","meal_delivery"],
          maxResultCount: 20, languageCode: "zh-TW", regionCode: "TW", rankPreference: "DISTANCE",
          locationRestriction: { circle: { center: { latitude: lat, longitude: lng }, radius: r } },
        }),
      }, SEARCH_MASK);
      return res.ok ? { ...res, body: filterFood(res.body as { places?: [] }) } : res;
    };
  } else if (sub === "details" && req.method === "GET") {
    const id = url.searchParams.get("id") ?? "";
    if (!id) return fail("缺少 id");
    key = `details:${id}`;
    ttl = TTL_DETAILS_MS;
    run = () => google(`places/${encodeURIComponent(id)}?languageCode=zh-TW&regionCode=TW`, { method: "GET" }, DETAIL_MASK);
  } else {
    return fail("not found", 404);
  }

  const cached = await cacheGet(key, ttl);
  if (cached) return json(cached, 200, { "X-Cache": "HIT" });

  const { subject, limit } = await subjectOf(req);
  const { data: allowed } = await admin.rpc("bump_usage", { p_subject: subject, p_limit: limit });
  if (allowed === false) return fail("今日查詢次數已達上限，明天再試", 429);

  const result = await run();
  if (!result.ok) return json(result.body, result.status);
  await cachePut(key, result.body);
  return json(result.body, 200, { "X-Cache": "MISS" });
});
