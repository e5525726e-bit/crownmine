// Google Places API (New) 代理
// - 金鑰只存在伺服器（GOOGLE_PLACES_API_KEY secret），前端不再持有
// - 結果快取：搜尋 7 天、店家詳細資料與照片 30 天（Google 允許最多 30 天）
// - 每日用量限制只為防止濫用（程式亂刷），正常使用不會碰到；
//   付費方案（pro）之後用於免廣告等好處，額度也放寬
// 路徑：
//   POST /places/search   {query, lat?, lng?}
//   POST /places/nearby   {lat, lng, radius}
//   GET  /places/details?id=<place_id>
//   GET  /places/photo?name=<photo name>&w=<maxWidthPx>   → 直接回傳圖片內容（後端代抓）
import { createClient } from "npm:@supabase/supabase-js@2";

const GOOGLE_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

// 每日上限
// - 個人（[免費, 付費]）：點開店家、附近搜尋、照片；未登入以 IP 計，額度同免費
// - 搜尋／地圖列店家：個人不限，改用「全站總量」保護帳單，另有每 IP 防機器人上限
const LIMITS: Record<string, [number, number]> = {
  details: [100, 500],
  photo: [3000, 10000],
};
const GLOBAL_LIMITS: Record<string, number> = { search: 300, nearby: 1000 };
const IP_LIMITS: Record<string, number> = { search: 2000, nearby: 2000 };
const LOGIN_REQUIRED = new Set<string>();
const UPGRADE_HINT: Record<string, string> = {
  search: "今天全站看地圖與搜尋的次數已達上限，明天再試（有評價的店還是看得到）",
  details: "今日查詢次數已達上限，明天再試",
  nearby: "今天全站查看地圖店家的次數已達上限，明天再試（有評價的店還是看得到）",
  photo: "今日照片瀏覽次數已達上限，明天再試",
};
const TTL_SEARCH_MS = 7 * 24 * 3600 * 1000;
const TTL_DETAILS_MS = 30 * 24 * 3600 * 1000;

const SEARCH_MASK = "places.id,places.displayName,places.formattedAddress,places.location,places.types," +
  "places.primaryType,places.primaryTypeDisplayName,places.photos,places.businessStatus," +
  "places.googleMapsUri";  // 不要 priceLevel：那會落到較貴的 Enterprise 計費
const TEXT_MASK = SEARCH_MASK + ",nextPageToken";  // 只有文字搜尋有分頁
// 店家頁只留地址（不要營業時間、電話、網站、價位：這些是 Google 較貴的計費等級，
// 拿掉後店家頁每月免費額度從 1,000 次變 5,000 次）
const DETAIL_MASK = "id,displayName,formattedAddress,location,types,primaryType,primaryTypeDisplayName," +
  "photos,businessStatus,googleMapsUri";

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

type Caller = { subject: string; plan: "free" | "pro"; signedIn: boolean };

async function callerOf(req: Request): Promise<Caller> {
  const auth = req.headers.get("authorization") ?? "";
  if (auth.startsWith("Bearer ") && auth.slice(7) !== ANON_KEY) {
    try {
      const client = createClient(SUPABASE_URL, ANON_KEY, {
        global: { headers: { Authorization: auth } },
        auth: { persistSession: false },
      });
      const { data } = await client.auth.getUser();
      if (data.user) {
        const { data: plan } = await admin.rpc("effective_plan", { p_user: data.user.id });
        return { subject: `user:${data.user.id}`, plan: plan === "pro" ? "pro" : "free", signedIn: true };
      }
    } catch (_) { /* 視為未登入 */ }
  }
  const ip = (req.headers.get("x-forwarded-for") ?? "unknown").split(",")[0].trim();
  return { subject: `ip:${ip}`, plan: "free", signedIn: false };
}

/// 檢查並累加某功能的今日用量；回傳 null 表示允許，否則是錯誤回應
async function gate(req: Request, feature: string): Promise<Response | null> {
  const caller = await callerOf(req);
  if (LOGIN_REQUIRED.has(feature) && !caller.signedIn) return fail("請先登入才能使用這個功能", 401);
  if (feature in GLOBAL_LIMITS) {
    // 先擋機器人（每 IP），再看全站總量
    const ip = (req.headers.get("x-forwarded-for") ?? "unknown").split(",")[0].trim();
    const { data: ipOk } = await admin.rpc("bump_usage", { p_subject: `ip:${ip}:${feature}`, p_limit: IP_LIMITS[feature] });
    if (ipOk === false) return fail("這個網路今天的查詢次數過多，明天再試", 429);
    const { data: allOk } = await admin.rpc("bump_usage", { p_subject: `global:${feature}`, p_limit: GLOBAL_LIMITS[feature] });
    if (allOk === false) return fail(UPGRADE_HINT[feature], 429);
    return null;
  }
  const limit = LIMITS[feature][caller.plan === "pro" ? 1 : 0];
  const { data: allowed } = await admin.rpc("bump_usage", { p_subject: `${caller.subject}:${feature}`, p_limit: limit });
  if (allowed === false) return fail(UPGRADE_HINT[feature], 429);
  return null;
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
  "food","bar_and_grill","cafeteria","confectionery","donut_shop","bagel_shop","acai_shop","chocolate_shop","candy_store",
  "snack_bar","bistro","tea_store","dessert_restaurant","deli","food_store"]);
const NOT_FOOD = new Set(["supermarket","grocery_store","convenience_store","wholesaler","butcher_shop","health_food_store",
  "department_store","shopping_mall","liquor_store"]);
// 分類過濾可指定的類型：白名單內或以 _restaurant 結尾
const FOOD_TYPES = { has: (t: string) => FOOD.has(t) || /^[a-z_]+_restaurant$/.test(t) };
// 附近搜尋預設涵蓋的餐飲類型（不含 food_store：會撈到超市、肉舖）
const NEARBY_DEFAULT_TYPES = ["restaurant","cafe","coffee_shop","bakery","bar","pub","wine_bar","meal_takeaway","meal_delivery",
  "food_court","ice_cream_shop","dessert_shop","dessert_restaurant","tea_house","tea_store","juice_shop","sandwich_shop","snack_bar",
  "bistro","diner","noodle_shop","donut_shop","bagel_shop","cafeteria","bar_and_grill","steak_house","acai_shop"];
function isFood(p: { types?: string[]; primaryType?: string }) {
  const ok = (t: string) => FOOD.has(t) || t.endsWith("_restaurant");
  if (p.primaryType && ok(p.primaryType) && p.primaryType !== "food_store") return true;
  const types = p.types ?? [];
  if (types.some((t) => NOT_FOOD.has(t))) return false;
  return types.some(ok);
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
    // 尺寸只分兩級（縮圖／大圖），同一張照片最多只向 Google 要兩次，其餘走快取
    const wantW = Number(url.searchParams.get("w") ?? "800");
    const w = wantW <= 400 ? 400 : 800;
    if (!name.startsWith("places/")) return fail("bad photo name");
    const key = `photo:${name}:${w}`;
    let uri = (await cacheGet(key, TTL_DETAILS_MS)) as string | null;
    if (!uri) {
      const blocked = await gate(req, "photo");
      if (blocked) return blocked;
      const res = await fetch(`https://places.googleapis.com/v1/${name}/media?maxWidthPx=${w}&skipHttpRedirect=true&key=${GOOGLE_KEY}`);
      const body = await res.json().catch(() => ({}));
      uri = body.photoUri;
      if (!uri) return fail("取得照片失敗", 502);
      await cachePut(key, uri);
    }
    // 直接把圖片內容抓回來送給 App（瀏覽器對 Google 圖片主機有跨網域限制，轉址會被擋）
    const img = await fetch(uri);
    if (!img.ok) return fail("取得照片失敗", 502);
    return new Response(img.body, {
      status: 200,
      headers: {
        "Content-Type": img.headers.get("content-type") ?? "image/jpeg",
        "Cache-Control": "public, max-age=604800, immutable",
        "X-Cache": "PROXY",
        ...CORS,
      },
    });
  }

  // 其餘：搜尋、附近、詳細資料
  let key = "";
  let ttl = TTL_SEARCH_MS;
  let feature = "";
  let run: () => Promise<{ ok: boolean; status: number; body: unknown }>;

  if (sub === "search" && req.method === "POST") {
    const { query, lat, lng, radius, type, bounds, pages, strict } = await req.json().catch(() => ({}));
    const q = String(query ?? "").trim();
    if (!q) return fail("缺少 query");
    const hasPos = typeof lat === "number" && typeof lng === "number";
    const r = Math.min(20000, Math.max(100, Number(radius ?? 5000)));
    // 縣市範圍（嚴格限制）：四個數字都要合理才採用
    const b = bounds && typeof bounds === "object" ? bounds as Record<string, unknown> : null;
    const num = (v: unknown) => typeof v === "number" && Number.isFinite(v) ? v : null;
    const rect = b && num(b.minLat) !== null && num(b.minLng) !== null && num(b.maxLat) !== null && num(b.maxLng) !== null
      && (b.minLat as number) < (b.maxLat as number) && (b.minLng as number) < (b.maxLng as number)
      ? { low: { latitude: b.minLat as number, longitude: b.minLng as number }, high: { latitude: b.maxLat as number, longitude: b.maxLng as number } }
      : null;
    const near = rect
      ? `rect:${rect.low.latitude}:${rect.low.longitude}:${rect.high.latitude}:${rect.high.longitude}`
      : hasPos ? `${lat.toFixed(2)}:${lng.toFixed(2)}:${Math.round(r / 500)}` : "tw";
    // 類型：未指定 → 餐廳；"any" → 不限（靠關鍵字，結果仍會過濾成餐飲）；其他需在白名單內
    const t = typeof type === "string" && type ? type : "restaurant";
    const includedType = t === "any" ? undefined : (FOOD_TYPES.has(t) ? t : "restaurant");
    // 一次最多拿幾頁（每頁 20 家、每頁各算一次）；地圖範圍內列店家時用 3 頁 = 60 家
    const nPages = Math.min(3, Math.max(1, Number(pages ?? 1) || 1));
    // strict：即使不限類型也只留餐飲業（地圖用）
    const keepFoodOnly = !!includedType || strict === true;
    key = `search:${q.toLowerCase()}:${near}:${includedType ?? "any"}:${nPages}:${keepFoodOnly ? "f" : "a"}`;
    feature = "search";
    run = async () => {
      const location = rect
        ? { locationRestriction: { rectangle: rect } }
        : {
          locationBias: !hasPos
            ? { rectangle: { low: { latitude: 21.8, longitude: 118.2 }, high: { latitude: 26.4, longitude: 122.1 } } }
            : { circle: { center: { latitude: lat, longitude: lng }, radius: r } },
        };
      const all: unknown[] = [];
      let pageToken: string | undefined;
      let last: { ok: boolean; status: number; body: unknown } = { ok: true, status: 200, body: {} };
      for (let i = 0; i < nPages; i++) {
        last = await google("places:searchText", {
          method: "POST",
          body: JSON.stringify({
            textQuery: q, ...(includedType ? { includedType } : {}), regionCode: "TW", languageCode: "zh-TW", pageSize: 20,
            ...location, ...(pageToken ? { pageToken } : {}),
          }),
        }, TEXT_MASK);
        if (!last.ok) return last;
        const body = last.body as { places?: unknown[]; nextPageToken?: string };
        all.push(...(body.places ?? []));
        pageToken = body.nextPageToken;
        if (!pageToken) break;
      }
      const merged = { places: all as Array<{ types?: string[]; primaryType?: string }> };
      // 關鍵字搜尋（不限類型）預設不過濾：手搖飲、小吃攤這類店 Google 常沒給餐飲類型
      return { ok: true, status: 200, body: keepFoodOnly ? filterFood(merged) : merged };
    };
  } else if (sub === "nearby" && req.method === "POST") {
    const { lat, lng, radius, types } = await req.json().catch(() => ({}));
    if (typeof lat !== "number" || typeof lng !== "number") return fail("缺少座標");
    const r = Math.min(3000, Math.max(100, Number(radius ?? 1000)));
    // 分類過濾：只接受白名單內的類型，最多 20 個；沒有就用預設的餐飲類型
    const wanted = Array.isArray(types)
      ? (types as unknown[]).filter((x): x is string => typeof x === "string" && FOOD_TYPES.has(x)).slice(0, 20)
      : [];
    const includedTypes = wanted.length ? wanted : NEARBY_DEFAULT_TYPES;
    key = `nearby:${lat.toFixed(3)}:${lng.toFixed(3)}:${Math.round(r / 100)}:${includedTypes.join(",")}`;
    feature = "nearby";
    run = async () => {
      const res = await google("places:searchNearby", {
        method: "POST",
        body: JSON.stringify({
          includedTypes,
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
    feature = "details";
    run = () => google(`places/${encodeURIComponent(id)}?languageCode=zh-TW&regionCode=TW`, { method: "GET" }, DETAIL_MASK);
  } else {
    return fail("not found", 404);
  }

  // 快取命中不計次（不花錢）；只有真的要問 Google 時才計次
  const cached = await cacheGet(key, ttl);
  if (cached) return json(cached, 200, { "X-Cache": "HIT" });
  const blocked = await gate(req, feature);
  if (blocked) return blocked;

  const result = await run();
  if (!result.ok) return json(result.body, result.status);
  await cachePut(key, result.body);
  return json(result.body, 200, { "X-Cache": "MISS" });
});
