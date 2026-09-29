# 美食地圖（CrownMine）

> 只屬於這個 App 的餐廳評價。店家資料來自 Google，評價完全獨立，看不到也不會抓取 Google 的評論。

目前狀態：**開發中，尚未上架**。程式碼可通過 `flutter analyze` 與 `flutter test`，
需要接上你自己的 Google 與 Supabase 帳號才能在手機上跑起來（步驟見下方）。

## 評價方式：四種核心判斷 + 附加標籤

| 核心判斷 | 意思 | 圖案 |
|---|---|---|
| 皇冠 | 真心推薦 | `assets/icons/crown.svg` |
| 🤑 見錢眼開 | 老子有錢不差錢 | `assets/icons/money_face.svg` |
| 綠燈（紅綠燈造型） | 普通中規中矩 | `assets/icons/green_light.svg` |
| 地雷 | 普通又貴 | `assets/icons/landmine.svg` |

| 附加標籤（可複選） | 意思 | 圖案 |
|---|---|---|
| 火焰 | 超好吃／必吃 | `assets/icons/fire.svg` |
| IG 網紅店 | 社群上很紅的店 | `assets/icons/ig.svg` |
| 網美店 | 拍照好看，重點不在吃 | `assets/icons/camera.svg` |
| 適合約會 | 氣氛好，帶另一半來剛好 | `assets/icons/cheers.svg` |
| 大便 | 難吃／態度環境很差 | `assets/icons/poop.svg` |

同一家店可以同時是「真心推薦」和「IG 網紅店」。地圖上大頭針顯示核心判斷，
至少三分之一的評價標了 IG 網紅店時，左上角會多一個 IG 徽章。
已上線的資料庫升級：Actions → **Supabase 執行 SQL**（預設跑 `0003a`、`0003b`）。

## 功能

- **找店家**：透過 Google Places API (New) 搜尋，只列出餐飲業（餐廳、咖啡廳、烘焙、酒吧、外帶／外送）。
  FieldMask 完全不要求 `rating`、`userRatingCount`、`reviews`，Google 的評價從頭到尾不會進到 App。
- **評價地圖**：Google 地圖上只顯示這個 App 有評價的店家。原本 Google 的紅色大頭針換成我們的大頭針：針頭放最多人給的那種圖案，外框是該標記的顏色。評價越多的店針越大、顯示評價數、浮在其他針上面（1–2 則小、3–9 則中、10 則以上大）。點針看統計、進店家頁。針的基準大小在 `features/map/verdict_marker.dart` 的 `kPinHeadSize`。
- **附近餐廳**：用手機定位找 500 公尺／1 公里／2 公里內的餐飲店家。
- **找評價**：只在這個 App 的評價資料庫裡搜尋，空白搜尋時顯示評價最多的店家排行。
- **店家頁**：Google 的基本資料（地址、電話、營業時間、照片）＋這個 App 的四種標記統計與評價列表。
- **寫評價**：選一個標記、寫至少 10 個字的心得、選填每人消費金額、造訪日期、最多 6 張照片、消費證明（收據照片，只有本人和管理員看得到，其他人看到「附消費證明」標記）。一人一店一則，可修改、可刪除。
- **帳號**：Email 註冊登入，瀏規不需登入，發表才需要。可修改顯示名稱、刪除帳號（Apple 上架必要）。
- **內容管理**（App Store／Play 對使用者內容的必要條件）：每則評價可檢舉、可封鎖使用者；同一則被 3 人檢舉自動隱藏待審；使用條款與社群規範頁；聯絡信箱。

## 設計原則（Apple 風格）

外觀依 Apple Human Interface Guidelines；手感依 [emilkowalski/skills](https://github.com/emilkowalski/skills) 的 `apple-design`：

- **按下就有反應**：可點的卡片在按下的瞬間縮小 3%，放開用彈簧回彈（`widgets/press_scale.dart`）。
- **彈簧、可中斷**：動畫用阻尼比與回應時間描述，從當下的值接續，不用固定秒數（`theme/motion.dart`）。
- **材質與層次**：導覽列、分頁列、底部動作列都是半透明毛玻璃，內容從底下滑過（`widgets/apple_bars.dart`）。
- **字體**：字級、字距、行距一起設定，大字負字距、小字近零；預設使用系統字型（`theme/apple_theme.dart`）。
- **減少動態**：系統開啟時改用透明度回饋、取消過渡動畫。
- **回饋有節制**：只在選標記、送出成功時給輕微觸覺回饋；確認對話框只用在刪除、封鎖這類不可逆動作。
- **iOS 元件**：分頁列、分段控制、搜尋欄、動作選單、日期選擇器、返回手勢都用 Cupertino 版本。

## 技術架構

```
Flutter（iOS + Android + Web 同一份程式碼）
 ├─ Google Maps SDK / JS          ← 地圖分頁的底圖（金鑰在前端，請限制只能用 Maps SDK）
 └─ Supabase
     ├─ Postgres + Auth + Storage  ← 帳號、評價、照片、檢舉、封鎖
     └─ Edge Function `places`     ← Google Places API (New) 代理：
                                      金鑰藏在伺服器、快取 30 天、每日用量限制
                                      （登入 300 次／未登入每 IP 100 次）
```

第一次或更新後端函式：Actions → **Supabase 部署後端函式** → Run workflow，貼上 Supabase 權杖。

### 方案與每日上限（後端 `LIMITS`）

成長期策略：**全部免費、額度寬鬆、先不放廣告**。上限只用來防止程式亂刷，一般人一天用不到。
付費方案（pro）先保留在後端，之後用於免廣告等好處。

| 功能 | 免費 | 付費（pro） |
|---|---|---|
| 搜尋店家、店家頁 | 300 | 1,000 |
| 附近餐廳、地圖全餐飲店 | 100 | 1,000 |
| 店家照片 | 300 | 2,000 |
| 寫評價、看評價、地圖上有評價的店 | 不限 | 不限 |

快取命中不計次。付費身分存在 `profiles.plan` / `plan_until`，之後由內購服務（如 RevenueCat webhook）寫入。

## 不裝 Flutter 也能試用（Android）

每次推到 `main`，GitHub Actions 會自動建置 Android 安裝檔並放在
<https://github.com/e5525726e-bit/crownmine/releases/tag/latest>。
手機瀏覽器打開該頁，下載 `crownmine-android.apk` 安裝即可（需允許安裝未知來源應用程式）。

要讓 APK 真的能連上 Google 與 Supabase，先到 GitHub repo 的
**Settings → Secrets and variables → Actions → New repository secret** 新增三個 secret：
`GOOGLE_PLACES_API_KEY`、`SUPABASE_URL`、`SUPABASE_ANON_KEY`（申請方式見下方第 2、3 步），
然後到 **Actions → Android APK → Run workflow** 重新建置。

## 從零開始跑起來

### 1. 安裝 Flutter

Windows 使用者請直接看 [SETUP-windows.md](SETUP-windows.md)，有一鍵安裝腳本。
其他平台依照 <https://docs.flutter.dev/get-started/install> 安裝 Flutter（stable）。
- 要跑 Android：安裝 Android Studio（含 Android SDK）。
- 要跑 iPhone：需要 Mac 並安裝 Xcode。

執行 `flutter doctor` 確認沒有紅字。

### 2. 建立 Google Cloud 專案並開啟 Places API (New)

1. 到 <https://console.cloud.google.com/> 建立專案。
2. 「API 和服務」→「啟用 API」→ 依序搜尋並啟用這三個：
   - **Places API (New)**（找店家）
   - **Maps SDK for Android**（地圖分頁，Android）
   - **Maps SDK for iOS**（地圖分頁，iPhone）
3. 「憑證」→ 建立 API 金鑰（一把金鑰三個 API 共用）。
4. 建議限制金鑰：「API 限制」只勾上面三個；「應用程式限制」正式上架前再設定成 Android／iOS 應用程式。
5. 需要綁定付款方式。Google 每月有免費額度，個人測試通常用不到錢；正式上線後費用依搜尋次數計算。

### 3. 建立 Supabase 專案

1. 到 <https://supabase.com/> 建立免費專案（Region 選 Northeast Asia (Tokyo) 離台灣最近）。
2. 左側 **SQL Editor** → 新查詢 → 把 `supabase/migrations/0001_init.sql` 整份貼上 → Run。
   這會建立所有資料表、權限規則、檢舉自動隱藏、刪除帳號功能與兩個 Storage bucket。
3. 左側 **Authentication → Providers → Email**：測試期間可以把「Confirm email」關掉，註冊就能直接登入。
4. 左側 **Project Settings → API**：複製 **Project URL** 與 **anon / publishable key**。

### 4. 填入設定

```bash
cp dart_defines.example.json dart_defines.json
```

用編輯器打開 `dart_defines.json`，填入上面拿到的三個值（`SUPPORT_EMAIL` 填你的聯絡信箱）。
這個檔案已在 `.gitignore`，不會被提交。

然後執行一次，把 Google 金鑰同步到地圖 SDK 需要的原生設定檔（也都不會被提交）：

```bash
dart run tool/sync_keys.dart
```

### 5. 在手機上執行

用 USB 接上手機（Android 要開啟開發人員選項的 USB 偵錯），或開模擬器，然後：

```bash
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

不需要任何商店開發者帳號就能在自己手機上測試：
- **Android**：`flutter build apk --dart-define-from-file=dart_defines.json`，把 `build/app/outputs/flutter-apk/app-release.apk` 傳到手機安裝即可。
- **iPhone**：需要 Mac + Xcode，用免費 Apple ID 簽章可以裝在自己的手機（7 天需重新安裝）。

### 6. 檢查與測試

```bash
flutter analyze
flutter test
```

## 上架前還要做的事（先不做，滿意後再說）

- 換 App 名稱、icon、四種標記的正式圖案。
- 把 `GoogleAttribution` 的文字換成 Google 官方的「Powered by Google」圖檔（[品牌規範](https://developers.google.com/maps/documentation/places/web-service/policies)）。
- 使用條款請律師看過；補上隱私權政策網址（兩個商店都要求）。
- Supabase 開啟 Email 確認、設定自訂 SMTP；管理後台審核檢舉（目前可直接在 Supabase Table Editor 操作 `reports` 與 `reviews.status`）。
- 若之後加 Google／Facebook 登入，Apple 規定必須同時提供「Sign in with Apple」。
- Apple Developer Program（每年 99 美元）與 Google Play 開發者帳號（一次 25 美元）。

## Google 資料使用規則（已在程式中遵守）

- `place_id` 可永久保存；店名、地址等其他欄位快取不超過 30 天（`places.cached_at`，寫評價時會重新寫入）。
- 顯示 Google 資料的畫面都有來源標示。
- 不顯示、不儲存 Google 的評分與評論。
