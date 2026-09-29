$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$zip=Join-Path $project 'release\FiddlerChinese.zip'
$work=Join-Path $project ('test-output\release-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$count=0
function Assert-Release($value,[string]$message){if(!$value){throw "FAIL: $message"};$script:count++;Write-Output "PASS: $message"}
$checksum=(Get-Content -LiteralPath "$zip.sha256" -Raw).Trim()
Assert-Release ($checksum -match '^([0-9a-fA-F]{64})\s+FiddlerChinese\.zip$') 'release checksum format'
Assert-Release ((Get-FileHash -LiteralPath $zip).Hash -eq $Matches[1]) 'release checksum matches archive'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$package=Join-Path $work 'package'
[IO.Compression.ZipFile]::ExtractToDirectory($zip,$package)
foreach($file in @('Install.ps1','Installer.Common.ps1','Uninstall.ps1','install-online.ps1','Scripts\FiddlerChinese.dll','Scripts\FiddlerChinese\FiddlerTexts.txt','Scripts\FiddlerChinese\FiddlerTexts.context.txt')){
    Assert-Release (Test-Path -LiteralPath (Join-Path $package $file) -PathType Leaf) "offline/online package contract: $file"
}
Assert-Release (!(Test-Path "$package\Restore.ps1")) 'obsolete restore script is absent'
Assert-Release (@(Get-ChildItem -LiteralPath $package -Filter '*.cmd').Count -eq 1) 'double-click launcher included'
foreach($file in @('FiddlerTexts.txt','FiddlerTexts.context.txt')){
    Assert-Release ((Get-FileHash -LiteralPath "$package\Scripts\FiddlerChinese\$file").Hash -eq (Get-FileHash -LiteralPath "$project\translations\$file").Hash) "single source of translations: $file"
}
$target=Join-Path $work 'portable target'
New-Item -ItemType Directory -Path $target | Out-Null
Set-Content -LiteralPath "$target\Fiddler.exe" -Value 'fixture only; never executed'
# Only this isolated test process overrides process detection.
function Get-Process {param($Name,$ErrorAction)}
& "$package\Install.ps1" -FiddlerPath $target
Assert-Release ((Get-FileHash -LiteralPath "$target\Scripts\FiddlerChinese.dll").Hash -eq (Get-FileHash -LiteralPath "$package\Scripts\FiddlerChinese.dll").Hash) 'generated release installs its DLL in a path with spaces'
Assert-Release (!(Test-Path "$target\localization-backups")) 'release install creates no backup folder'
& "$package\Uninstall.ps1" -FiddlerPath $target
Assert-Release (!(Test-Path -LiteralPath "$target\Scripts\FiddlerChinese.dll")) 'generated release uninstalls the plugin'
"PASS: $count release packaging assertions." | Set-Content -LiteralPath "$project\test-output\release-results.txt"
Write-Output "ALL PASSED: $count"