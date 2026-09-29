param([string]$FiddlerPath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\Installer.Common.ps1"
$targetRoot=Resolve-FiddlerInstallPath $FiddlerPath
if(Get-Process -Name Fiddler -ErrorAction SilentlyContinue){throw 'Please close Fiddler before restoring.'}
$pointer="$targetRoot\Scripts\FiddlerChinese\installation.json"
if(!(Test-Path -LiteralPath $pointer)){throw 'No installation record was found.'}
$manifest=Get-Content -LiteralPath $pointer -Raw | ConvertFrom-Json
$backup=[IO.Path]::GetFullPath($manifest.Backup)
if($manifest.Root -ne $targetRoot -or !$backup.StartsWith("$targetRoot\localization-backups\",[StringComparison]::OrdinalIgnoreCase)){throw 'Backup path validation failed.'}
$allowed=@('FiddlerChinese.dll','FiddlerChinese\FiddlerTexts.txt','FiddlerChinese\FiddlerTexts.context.txt','FiddlerChinese\installation.json','FdToChinese.dll')
$savedCurrent=Join-Path $backup ('before-restore-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
foreach($record in $manifest.Records){
    if($allowed -notcontains $record.Relative){throw 'Unexpected path in installation record.'}
    $destination=Join-Path "$targetRoot\Scripts" $record.Relative
    if(Test-Path -LiteralPath $destination){
        $preserved=Join-Path $savedCurrent $record.Relative
        New-Item -ItemType Directory -Path (Split-Path $preserved) -Force | Out-Null
        Copy-Item -LiteralPath $destination -Destination $preserved
    }
    if($record.HadOriginal){Copy-Item -LiteralPath (Join-Path $backup $record.Relative) -Destination $destination -Force}
    elseif(Test-Path -LiteralPath $destination){Remove-Item -LiteralPath $destination}
}
Write-Output "Previous files restored. Current translations preserved at: $savedCurrent"
