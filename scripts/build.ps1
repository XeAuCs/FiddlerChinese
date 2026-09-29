param([string]$FiddlerPath)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
. "$project\installer\Installer.Common.ps1"
$FiddlerPath = Resolve-FiddlerInstallPath $FiddlerPath
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$outputDir = Join-Path $project 'bin'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
& $compiler /nologo /target:library /optimize+ /codepage:65001 "/out:$outputDir\FiddlerChinese.dll" /r:System.Windows.Forms.dll /r:System.Drawing.dll "/r:$FiddlerPath\Fiddler.exe" "$project\src\Localization.cs" "$project\src\Plugin.cs"
if($LASTEXITCODE -ne 0) {throw 'Plugin compilation failed.'}
Write-Output "Built $outputDir\FiddlerChinese.dll"