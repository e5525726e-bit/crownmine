# 皇冠與地雷：Windows 開發環境一鍵安裝
# 用法：在「Windows PowerShell」貼上以下一行執行（不需要系統管理員）：
#   Set-ExecutionPolicy -Scope Process Bypass -Force; .\tool\setup-windows.ps1
#
# 會安裝：Git、Android Studio（含 Android SDK）、Flutter SDK（放在 C:\dev\flutter）
# 已安裝的會自動略過。

$ErrorActionPreference = 'Stop'
$flutterDir = 'C:\dev\flutter'

function Say($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

# 1. Git
if (Get-Command git -ErrorAction SilentlyContinue) {
  Say 'Git 已安裝，略過'
} else {
  Say '安裝 Git'
  winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
}

# 2. Android Studio
$studio = Get-ChildItem 'C:\Program Files\Android\Android Studio\bin\studio64.exe' -ErrorAction SilentlyContinue
if ($studio) {
  Say 'Android Studio 已安裝，略過'
} else {
  Say '安裝 Android Studio（檔案很大，請耐心等）'
  winget install --id Google.AndroidStudio -e --accept-source-agreements --accept-package-agreements
}

# 3. Flutter SDK
if (Test-Path "$flutterDir\bin\flutter.bat") {
  Say 'Flutter 已安裝，略過'
} else {
  Say "下載 Flutter 到 $flutterDir"
  New-Item -ItemType Directory -Force -Path 'C:\dev' | Out-Null
  & "$env:ProgramFiles\Git\cmd\git.exe" clone -b stable --depth 1 https://github.com/flutter/flutter.git $flutterDir
}

# 4. 加入 PATH（使用者層級）
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$flutterDir\bin*") {
  Say '把 Flutter 加進 PATH'
  [Environment]::SetEnvironmentVariable('Path', "$userPath;$flutterDir\bin", 'User')
}
$env:Path = "$env:Path;$flutterDir\bin"

# 5. 第一次執行 flutter（會自動下載 Dart 等工具）
Say '初始化 Flutter（第一次會花幾分鐘）'
& "$flutterDir\bin\flutter.bat" --version

Say '完成！接下來請：'
Write-Host '  1. 打開 Android Studio 一次，照精靈按 Next 到底，讓它下載 Android SDK。'
Write-Host '  2. 關掉這個 PowerShell 視窗，重新打開一個新的。'
Write-Host '  3. 在新視窗執行：flutter doctor --android-licenses   （一路按 y）'
Write-Host '  4. 再執行：flutter doctor   把畫面截圖給 Claude。'
