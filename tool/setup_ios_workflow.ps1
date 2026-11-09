<#
Applies this repo's Windows -> iPhone workflow to another Flutter project:
  - codemagic.yaml (TestFlight + dev workflows) with your bundle ID
  - lib/dev_preview.dart + device_preview package (iPhone frame in Chrome)
  - ITSAppUsesNonExemptEncryption in ios/Runner/Info.plist
  - iOS bundle ID in the Xcode project
  - signing-key entries in .gitignore

Usage (from this repo):
  .\tool\setup_ios_workflow.ps1 -ProjectPath C:\path\to\real_app -BundleId com.yusufali.realapp

Afterwards, add 2 lines to the target's lib/main.dart (the script reminds you).
#>
param(
    [Parameter(Mandatory)] [string] $ProjectPath,
    [Parameter(Mandatory)] [string] $BundleId
)
$ErrorActionPreference = 'Stop'
$kit = Split-Path $PSScriptRoot -Parent
$ProjectPath = (Resolve-Path $ProjectPath).Path

if (-not (Test-Path "$ProjectPath\pubspec.yaml")) { throw "No pubspec.yaml in $ProjectPath" }
if (-not (Test-Path "$ProjectPath\ios")) {
    throw "No ios/ folder. Run: flutter create --platforms=ios,android ."
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-Text($path, $text) { [IO.File]::WriteAllText($path, $text, $utf8) }

# 1. codemagic.yaml
$yaml = [IO.File]::ReadAllText("$kit\codemagic.yaml") -replace 'BUNDLE_ID: \S+', "BUNDLE_ID: $BundleId"
Write-Text "$ProjectPath\codemagic.yaml" $yaml
Write-Host "codemagic.yaml written"

# 2. Dev preview
Copy-Item "$kit\lib\dev_preview.dart" "$ProjectPath\lib\dev_preview.dart" -Force
Push-Location $ProjectPath
$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutter) { $flutter = 'C:\flutter\flutter\bin\flutter.bat' }
try { & $flutter pub add device_preview; if ($LASTEXITCODE) { throw "flutter pub add failed" } } finally { Pop-Location }
Write-Host "device_preview added"

# 3. Info.plist export compliance
$plistPath = "$ProjectPath\ios\Runner\Info.plist"
$plist = [IO.File]::ReadAllText($plistPath)
if ($plist -notmatch 'ITSAppUsesNonExemptEncryption') {
    $plist = ([regex]'(<dict>\r?\n)').Replace($plist, "`$1`t<key>ITSAppUsesNonExemptEncryption</key>`n`t<false/>`n", 1)
    Write-Text $plistPath $plist
    Write-Host "Info.plist updated"
}

# 4. Bundle ID in Xcode project (app target + RunnerTests)
$pbxPath = "$ProjectPath\ios\Runner.xcodeproj\project.pbxproj"
$pbx = [IO.File]::ReadAllText($pbxPath)
$pbx = $pbx -replace 'PRODUCT_BUNDLE_IDENTIFIER = [^;]*?\.RunnerTests;', "PRODUCT_BUNDLE_IDENTIFIER = $BundleId.RunnerTests;"
$pbx = $pbx -replace 'PRODUCT_BUNDLE_IDENTIFIER = (?![^;]*RunnerTests)[^;]+;', "PRODUCT_BUNDLE_IDENTIFIER = $BundleId;"
Write-Text $pbxPath $pbx
Write-Host "Bundle ID set to $BundleId"

# 5. .gitignore
$gi = "$ProjectPath\.gitignore"
if (-not (Test-Path $gi) -or -not (Select-String -Path $gi -Pattern 'ios_dist_key' -Quiet)) {
    Add-Content $gi "`n# iOS signing keys`nios_dist_key*`n*.p12`n*.p8`n*.mobileprovision"
    Write-Host ".gitignore updated"
}

Write-Host ""
Write-Host "Done. Remaining manual steps:" -ForegroundColor Green
Write-Host "  1. In lib/main.dart add:   import 'dev_preview.dart';"
Write-Host "     and as the first line of main():   setUpDevPreview();"
Write-Host "  2. Create the app in App Store Connect with bundle ID $BundleId"
Write-Host "  3. In Codemagic: add the repo, create env group 'ios_signing' with CERTIFICATE_PRIVATE_KEY"
Write-Host "     (reuse the same key as your test app)"
