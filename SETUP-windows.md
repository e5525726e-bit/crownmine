# Windows 安裝步驟（Android 版）

> iPhone 版需要 Mac 與 Xcode，Windows 只能建置 Android 版。

## 第一次安裝（約 30 分鐘，大多是下載時間）

1. 到 https://github.com/e5525726e-bit/crownmine 按綠色 **Code → Download ZIP**，解壓縮到 `C:\dev\crownmine`。
   （之後有 Git 了可以改用 `git clone`。）
2. 在開始功能表搜尋 **PowerShell**，打開「Windows PowerShell」（不用系統管理員）。
3. 貼上以下兩行，按 Enter：

   ```powershell
   cd C:\dev\crownmine
   Set-ExecutionPolicy -Scope Process Bypass -Force; .\tool\setup-windows.ps1
   ```

   這會安裝 Git、Android Studio、Flutter。中間跳出安裝視窗一律按「下一步」。
4. 安裝完照畫面提示：打開 Android Studio 一次讓它下載 Android SDK，然後**關掉 PowerShell 重新開一個**，執行：

   ```powershell
   flutter doctor --android-licenses
   flutter doctor
   ```

   `flutter doctor` 的結果截圖給 Claude 看。Chrome、Visual Studio 那幾項打叉沒關係，只需要 Flutter 和 Android toolchain 是綠色勾勾。

## 手機設定（一次就好）

1. 手機「設定 → 關於手機」連點「版本號碼」7 次，開啟開發人員選項。
2. 「設定 → 開發人員選項」開啟 **USB 偵錯**。
3. 用 USB 線接電腦，手機跳出「允許 USB 偵錯？」按允許。
4. PowerShell 執行 `flutter devices`，看到你的手機型號就對了。

沒有 Android 手機的話，Android Studio 裡可以建立模擬器：Android Studio → More Actions → Virtual Device Manager → Create device，選 Pixel 系列，下載一個系統映像即可。

## 填設定並執行

1. 把 `dart_defines.example.json` 複製一份改名 `dart_defines.json`，用記事本打開填入 Google 金鑰、Supabase URL 與 key（申請方式見 README）。
2. PowerShell 在 `C:\dev\crownmine` 執行：

   ```powershell
   dart run tool/sync_keys.dart
   flutter pub get
   flutter run --dart-define-from-file=dart_defines.json
   ```

   第一次建置約 5 到 10 分鐘，之後會快很多。App 會直接裝到手機上並開啟。

## 常見問題

- **`winget` 不是命令**：Windows 10 舊版沒有 winget，到 Microsoft Store 搜尋「應用程式安裝程式」更新後再試。
- **`flutter` 不是命令**：關掉 PowerShell 重新開，PATH 才會生效。
- **建置失敗提到 Java 或 Gradle**：打開 Android Studio → Settings → Languages & Frameworks → Android SDK → SDK Tools，確認 Android SDK Build-Tools 與 Command-line Tools 有勾選並套用。
- 其他錯誤：把整段紅字截圖給 Claude。
