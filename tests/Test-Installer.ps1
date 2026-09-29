$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$work=Join-Path $project ('test-output\online-installer-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$global:FiddlerInstallerTest_checks=0
function Assert-Installer($condition,[string]$label){
    if(!$condition){throw "FAIL: $label"}
    $global:FiddlerInstallerTest_checks++
    Write-Output "PASS: $label"
}
function Assert-Fails([scriptblock]$action,[string]$pattern,[string]$label){
    $failed=$false
    try { & $action | Out-Null } catch { $failed=$true; if($_.Exception.Message -notmatch $pattern){throw} }
    Assert-Installer $failed $label
}
function New-Fixture([string]$name){
    $path=Join-Path $work $name
    New-Item -ItemType Directory -Path "$path\Scripts" -Force | Out-Null
    Set-Content -LiteralPath "$path\Fiddler.exe" -Value 'fixture only'
    return $path
}
. "$project\installer\Installer.Common.ps1"
$global:FiddlerInstallerTest_candidates=@()
function Get-FiddlerInstallCandidates { $global:FiddlerInstallerTest_candidates }
$one=New-Fixture 'portable with spaces'
$two=New-Fixture 'second'
Assert-Fails {Resolve-FiddlerInstallPath} 'not detected' 'missing installation gets actionable error'
$global:FiddlerInstallerTest_candidates=@($one,$one)
Assert-Installer ((Resolve-FiddlerInstallPath) -eq $one) 'duplicate candidates are deduplicated'
$global:FiddlerInstallerTest_candidates=@($one,$two)
Assert-Fails {Resolve-FiddlerInstallPath} 'Multiple' 'ambiguous installations require an explicit path'
Assert-Installer ((Resolve-FiddlerInstallPath $one) -eq $one) 'explicit portable path is supported'
Assert-Fails {Resolve-FiddlerInstallPath "$work\not-installed"} 'not found' 'invalid explicit path is rejected'

# Only mock process discovery inside this test process, never stop the user's app.
$global:FiddlerInstallerTest_running=$true
function Get-Process {param($Name,$ErrorAction) if($global:FiddlerInstallerTest_running){[pscustomobject]@{Name='Fiddler'}}}
$offline=Join-Path $work 'offline-package'
New-Item -ItemType Directory -Path "$offline\Scripts\FiddlerChinese" -Force | Out-Null
foreach($file in @('Install.ps1','Installer.Common.ps1','Restore.ps1')){Copy-Item -LiteralPath "$project\installer\$file" -Destination $offline}
Set-Content -LiteralPath "$offline\Scripts\FiddlerChinese.dll" -Value 'installer byte-copy fixture; not an executable assembly'
Copy-Item -LiteralPath "$project\translations\FiddlerTexts.txt","$project\translations\FiddlerTexts.context.txt" -Destination "$offline\Scripts\FiddlerChinese"
Assert-Fails {& "$offline\Install.ps1" -FiddlerPath $one} 'close Fiddler' 'running Fiddler is not terminated'
Assert-Installer (!(Test-Path "$one\localization-backups")) 'running-app refusal changes no files'
$global:FiddlerInstallerTest_running=$false
Set-Content -LiteralPath "$one\Scripts\FdToChinese.dll" -Value 'legacy translator'
Set-Content -LiteralPath "$one\Scripts\OtherPlugin.dll" -Value 'unrelated plugin'
& "$offline\Install.ps1" -FiddlerPath $one
$first=Get-Content -LiteralPath "$one\Scripts\FiddlerChinese\installation.json" -Raw | ConvertFrom-Json
Assert-Installer ((Get-FileHash "$one\Scripts\FiddlerChinese.dll").Hash -eq (Get-FileHash "$offline\Scripts\FiddlerChinese.dll").Hash) 'installed DLL matches package'
Assert-Installer (!(Test-Path "$one\Scripts\FdToChinese.dll") -and (Test-Path "$($first.Backup)\FdToChinese.dll")) 'legacy translator is backed up and disabled'
Set-Content -LiteralPath "$one\Scripts\FiddlerChinese\FiddlerTexts.context.txt" -Value 'custom translation'
& "$offline\Install.ps1" -FiddlerPath $one
$second=Get-Content -LiteralPath "$one\Scripts\FiddlerChinese\installation.json" -Raw | ConvertFrom-Json
Assert-Installer ($first.Backup -ne $second.Backup) 'repeat installation creates a new backup'
& "$offline\Restore.ps1" -FiddlerPath $one
Assert-Installer ((Get-Content "$one\Scripts\FiddlerChinese\FiddlerTexts.context.txt" -Raw).Trim() -eq 'custom translation') 'restore recovers custom translations'
& "$offline\Restore.ps1" -FiddlerPath $one
Assert-Installer (!(Test-Path "$one\Scripts\FiddlerChinese.dll") -and (Test-Path "$one\Scripts\FdToChinese.dll")) 'restore recovers pre-install state'
Assert-Installer ((Get-Content "$one\Scripts\OtherPlugin.dll" -Raw).Trim() -eq 'unrelated plugin') 'unrelated plugin remains unchanged'

# Inject one copy failure after the DLL write; verify transactional rollback.
$global:FiddlerInstallerTest_injectFailure=$true
function Copy-Item {
    [CmdletBinding()]param([string[]]$LiteralPath,[string]$Destination,[switch]$Force)
    if($global:FiddlerInstallerTest_injectFailure -and $Destination -eq "$one\Scripts\FiddlerChinese\FiddlerTexts.txt") {
        $global:FiddlerInstallerTest_injectFailure=$false
        throw 'Injected copy failure'
    }
    Microsoft.PowerShell.Management\Copy-Item @PSBoundParameters
}
Assert-Fails {& "$offline\Install.ps1" -FiddlerPath $one} 'Injected copy failure' 'partial copy failure is reported'
Assert-Installer (!(Test-Path "$one\Scripts\FiddlerChinese.dll") -and (Test-Path "$one\Scripts\FdToChinese.dll")) 'partial install rolls back files'
Remove-Item Function:\Copy-Item

# Exercise the actual bootstrap with mocked GitHub responses and a harmless child installer.
# No network requests are sent and no production installer is launched against the real host.
$fake=Join-Path $work 'fake-release'
New-Item -ItemType Directory -Path "$fake\Scripts\FiddlerChinese" -Force | Out-Null
Set-Content -LiteralPath "$fake\Install.ps1" -Value 'param([string]$FiddlerPath) Set-Content -LiteralPath (Join-Path $FiddlerPath "bootstrap-ok.txt") -Value "installed"'
Set-Content -LiteralPath "$fake\Installer.Common.ps1" -Value '# fixture'
Set-Content -LiteralPath "$fake\Scripts\FiddlerChinese.dll" -Value 'fixture only'
Set-Content -LiteralPath "$fake\Scripts\FiddlerChinese\FiddlerTexts.txt" -Value 'File==fixture'
Set-Content -LiteralPath "$fake\Scripts\FiddlerChinese\FiddlerTexts.context.txt" -Value '// fixture'
$global:FiddlerInstallerTest_zip=Join-Path $work 'fixture.zip'
Compress-Archive -Path "$fake\*" -DestinationPath $global:FiddlerInstallerTest_zip
$global:FiddlerInstallerTest_hash=(Get-FileHash $global:FiddlerInstallerTest_zip).Hash
$global:FiddlerInstallerTest_mode='success'
$global:FiddlerInstallerTest_requested=@()
$global:FiddlerInstallerTest_downloadStage=''
# Define the switch with its actual signature to exercise the production invocation.
function Invoke-WebRequest {
    param([switch]$UseBasicParsing,[string]$Uri,$Headers,[int]$TimeoutSec,[string]$OutFile)
    $global:FiddlerInstallerTest_requested+=@($Uri)
    if($Uri.StartsWith('https://api.github.com/')) {
        throw '403 Forbidden: GitHub API unavailable in this regression fixture'
    }
    if($global:FiddlerInstallerTest_mode -eq 'network'){throw 'Simulated network failure'}
    $global:FiddlerInstallerTest_downloadStage=Split-Path $OutFile
    if($Uri.EndsWith('.sha256')) {
        if($global:FiddlerInstallerTest_mode -eq 'missing'){throw '404 Not Found'}
        $value=$global:FiddlerInstallerTest_hash
        if($global:FiddlerInstallerTest_mode -eq 'corrupt'){$value='0'*64}
        [IO.File]::WriteAllText($OutFile,"$value  FiddlerChinese.zip`n")
    } else {Copy-Item -LiteralPath $global:FiddlerInstallerTest_zip -Destination $OutFile}
}
$oldTls=[Net.ServicePointManager]::SecurityProtocol
& "$project\install-online.ps1" -Repository 'test/FiddlerChinese' -FiddlerPath $one
Assert-Installer (Test-Path "$one\bootstrap-ok.txt") 'bootstrap reaches installer and preserves a path with spaces'
Assert-Installer ($global:FiddlerInstallerTest_requested.Count -eq 2 -and $global:FiddlerInstallerTest_requested[0] -eq 'https://github.com/test/FiddlerChinese/releases/latest/download/FiddlerChinese.zip' -and $global:FiddlerInstallerTest_requested[1] -eq 'https://github.com/test/FiddlerChinese/releases/latest/download/FiddlerChinese.zip.sha256') 'latest release downloads directly without GitHub API'
Assert-Installer (!(Test-Path $global:FiddlerInstallerTest_downloadStage)) 'temporary download directory is cleaned'
Assert-Installer ([Net.ServicePointManager]::SecurityProtocol -eq $oldTls) 'original TLS settings are restored'
Remove-Item -LiteralPath "$one\bootstrap-ok.txt"
$global:FiddlerInstallerTest_mode='corrupt'
Assert-Fails {& "$project\install-online.ps1" -Repository 'test/FiddlerChinese' -FiddlerPath $one} 'checksum mismatch' 'corrupt download is rejected'
Assert-Installer (!(Test-Path "$one\bootstrap-ok.txt")) 'corrupt download never launches installer'
$global:FiddlerInstallerTest_mode='missing'
Assert-Fails {& "$project\install-online.ps1" -Repository 'test/FiddlerChinese' -FiddlerPath $one} "Cannot download 'FiddlerChinese.zip.sha256'" 'missing release asset is rejected'
Assert-Installer (!(Test-Path "$one\bootstrap-ok.txt")) 'missing checksum never launches installer'
$global:FiddlerInstallerTest_mode='network'
Assert-Fails {& "$project\install-online.ps1" -Repository 'test/FiddlerChinese' -FiddlerPath $one} 'Cannot download' 'network failure gives actionable error'
$global:FiddlerInstallerTest_mode='success'
$global:FiddlerInstallerTest_requested=@()
& "$project\install-online.ps1" -Repository 'test/FiddlerChinese' -FiddlerPath $one -Version 'v2.0.0'
Assert-Installer ($global:FiddlerInstallerTest_requested[0] -eq 'https://github.com/test/FiddlerChinese/releases/download/v2.0.0/FiddlerChinese.zip') 'explicit release version is supported'
Remove-Item -LiteralPath "$one\bootstrap-ok.txt"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$unsafe=Join-Path $work 'unsafe.zip'
$archive=[IO.Compression.ZipFile]::Open($unsafe,[IO.Compression.ZipArchiveMode]::Create)
try {$entry=$archive.CreateEntry('../escaped.txt');$stream=$entry.Open();$stream.WriteByte(65);$stream.Dispose()} finally {$archive.Dispose()}
$global:FiddlerInstallerTest_zip=$unsafe
$global:FiddlerInstallerTest_hash=(Get-FileHash $unsafe).Hash
Assert-Fails {& "$project\install-online.ps1" -Repository 'test/FiddlerChinese' -FiddlerPath $one} 'Unsafe path' 'archive path traversal is rejected before extraction'
Assert-Installer (!(Test-Path "$one\bootstrap-ok.txt")) 'unsafe archive never launches installer'
"PASS: $global:FiddlerInstallerTest_checks installer assertions (local fixtures; GitHub responses mocked)." | Set-Content -LiteralPath "$project\test-output\online-installer-results.txt"
Write-Output "ALL PASSED: $global:FiddlerInstallerTest_checks"
