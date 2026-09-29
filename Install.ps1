param([string]$FiddlerPath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\Installer.Common.ps1"
$targetRoot=Resolve-FiddlerInstallPath $FiddlerPath
if(Get-Process -Name Fiddler -ErrorAction SilentlyContinue){throw 'Please close Fiddler before installing.'}
$payload=Join-Path $PSScriptRoot 'Scripts'
if(!(Test-Path -LiteralPath "$payload\FiddlerChinese.dll")){$payload=Join-Path $PSScriptRoot 'package\Scripts'}
if(!(Test-Path -LiteralPath "$payload\FiddlerChinese.dll")){throw 'Plugin package was not found.'}
$required=@('FiddlerChinese.dll','FiddlerChinese\FiddlerTexts.txt','FiddlerChinese\FiddlerTexts.context.txt')
foreach($relative in $required){
    if(!(Test-Path -LiteralPath (Join-Path $payload $relative) -PathType Leaf)){throw "Incomplete package: $relative"}
}
$backup=Join-Path $targetRoot ('localization-backups\'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
try {New-Item -ItemType Directory -Path $backup -Force | Out-Null}
catch {throw "Cannot write to '$targetRoot'. If installed in Program Files, open PowerShell as administrator and rerun the command. $($_.Exception.Message)"}
$paths=@('FiddlerChinese.dll','FiddlerChinese\FiddlerTexts.txt','FiddlerChinese\FiddlerTexts.context.txt','FiddlerChinese\installation.json','FdToChinese.dll')
$records=@()
foreach($relative in $paths){
    $destination=Join-Path "$targetRoot\Scripts" $relative
    $saved=Join-Path $backup $relative
    $existed=Test-Path -LiteralPath $destination
    if($existed){New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null;Copy-Item -LiteralPath $destination -Destination $saved}
    $records+=@{Relative=$relative;HadOriginal=$existed}
}
$manifest=@{Root=$targetRoot;Backup=$backup;Records=$records;Version='2.0.0';Time=(Get-Date).ToString('s')}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$backup\manifest.json" -Encoding utf8
try {
New-Item -ItemType Directory -Path "$targetRoot\Scripts\FiddlerChinese" -Force | Out-Null
foreach($relative in $paths[0..2]){
    $destination=Join-Path "$targetRoot\Scripts" $relative
    Copy-Item -LiteralPath (Join-Path $payload $relative) -Destination $destination -Force
    if((Get-FileHash -LiteralPath $destination).Hash -ne (Get-FileHash -LiteralPath (Join-Path $payload $relative)).Hash){throw "Copy verification failed: $relative"}
}
# Disable only the legacy translator; its original was backed up above.
$legacy="$targetRoot\Scripts\FdToChinese.dll"
if(Test-Path -LiteralPath $legacy){
    $legacyFull=[IO.Path]::GetFullPath($legacy)
    $disabledFull=[IO.Path]::GetFullPath("$backup\FdToChinese.disabled.dll")
    if(!$legacyFull.StartsWith("$targetRoot\Scripts\",[StringComparison]::OrdinalIgnoreCase) -or !$disabledFull.StartsWith("$targetRoot\localization-backups\",[StringComparison]::OrdinalIgnoreCase)){throw 'Legacy plugin path validation failed.'}
    Move-Item -LiteralPath $legacyFull -Destination $disabledFull
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$targetRoot\Scripts\FiddlerChinese\installation.json" -Encoding utf8
} catch {
    $failure=$_
    foreach($record in $records){
        $destination=Join-Path "$targetRoot\Scripts" $record.Relative
        try {
            if($record.HadOriginal){Copy-Item -LiteralPath (Join-Path $backup $record.Relative) -Destination $destination -Force}
            elseif(Test-Path -LiteralPath $destination){Remove-Item -LiteralPath $destination}
        } catch {Write-Warning "Rollback incomplete for $($record.Relative). Original files: $backup"}
    }
    throw $failure
}
Write-Output "Installed Fiddler Chinese UI 2.0.0. Backup: $backup"
