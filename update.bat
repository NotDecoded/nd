@echo off
chcp 65001 >nul
title Ungoogled Chromium Auto Updater
color 0B

echo [INFO] 正在啟動自動更新程序，請稍候...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$script = Get-Content -Path '%~f0' -Raw; $ps_code = $script -replace '(?s)^.*?<#START_PS#>', ''; Invoke-Expression $ps_code"

echo.
pause
exit /b

<#START_PS#>
$ErrorActionPreference = "Stop"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Ungoogled Chromium Auto Updater & Cleaner" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/6] [INFO] 正在查詢 GitHub 上的最新版本..." -ForegroundColor Yellow
$repo = "macchrome/winchrome"
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -match "ungoogled-chromium.*(windows_x64|win64|binaries).*\.zip" } | Select-Object -First 1

    if (-not $asset) {
        Write-Host "[ERROR] 找不到對應的 Windows 64 位元更新包！" -ForegroundColor Red
        exit
    }
    $downloadUrl = $asset.browser_download_url
    $zipName = $asset.name
    Write-Host "[OK] 找到最新版本: $($release.tag_name)" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] 查詢失敗，請檢查網路連線或 GitHub API 限制。" -ForegroundColor Red
    exit
}

Write-Host "`n[2/6] [INFO] 檢查並關閉運行中的 Chromium 瀏覽器..." -ForegroundColor Yellow
$chromeProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
if ($chromeProcesses) {
    Stop-Process -Name "chrome" -Force
    Start-Sleep -Seconds 3
    Write-Host "[OK] 已強制關閉瀏覽器。" -ForegroundColor Green
} else {
    Write-Host "[OK] 瀏覽器目前未運行。" -ForegroundColor Green
}

Write-Host "`n[3/6] [INFO] 正在下載更新檔 (檔案較大，這可能需要幾分鐘)..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipName
    Write-Host "[OK] 下載完成！" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] 下載失敗，請檢查網路連線。" -ForegroundColor Red
    exit
}

Write-Host "`n[4/6] [INFO] 正在解壓縮更新檔..." -ForegroundColor Yellow
$tempExtract = ".\Temp_Chromium_Update"
if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
Expand-Archive -Path $zipName -DestinationPath $tempExtract -Force
Write-Host "[OK] 解壓縮完成。" -ForegroundColor Green

Write-Host "`n[5/6] [INFO] 備份使用者資料並清理舊內核..." -ForegroundColor Yellow
$targetFolder = ".\Chromium"
$extractedInnerFolder = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1

if (Test-Path $targetFolder) {
    $userDataPath = Join-Path $targetFolder "User Data"
    if (Test-Path $userDataPath) {
        Write-Host "      -> [INFO] 發現 User Data，正在遷移你的書籤與設定..." -ForegroundColor Cyan
        $newUserDataPath = Join-Path $extractedInnerFolder.FullName "User Data"
        Move-Item -Path $userDataPath -Destination $newUserDataPath -Force
    }
    Write-Host "      -> [INFO] 正在徹底刪除舊版本內核檔案..." -ForegroundColor Cyan
    Remove-Item -Path $targetFolder -Recurse -Force
}

Write-Host "      -> [INFO] 部署新版本內核..." -ForegroundColor Cyan
Rename-Item -Path $extractedInnerFolder.FullName -NewName $targetFolder
Write-Host "[OK] 核心替換完畢。" -ForegroundColor Green

Write-Host "`n[6/6] [INFO] 清理暫存檔與安裝包..." -ForegroundColor Yellow
Remove-Item $zipName -Force
Remove-Item $tempExtract -Recurse -Force
Write-Host "[OK] 垃圾檔案清理完畢。" -ForegroundColor Green

Write-Host "`n==================================================" -ForegroundColor Green
Write-Host "[SUCCESS] 更新成功！" -ForegroundColor Green
Write-Host "現在你可以進入 Chromium 資料夾，並雙擊 chrome.exe 開啟瀏覽器。" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
