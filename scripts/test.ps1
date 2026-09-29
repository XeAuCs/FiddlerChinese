param([string]$FiddlerPath)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
. "$project\installer\Installer.Common.ps1"
$FiddlerPath=Resolve-FiddlerInstallPath $FiddlerPath
& "$PSScriptRoot\build.ps1" -FiddlerPath $FiddlerPath
$bin=Join-Path $project 'bin'
$dict=Join-Path $bin 'FiddlerChinese'
New-Item -ItemType Directory -Path $dict -Force | Out-Null
Copy-Item -LiteralPath "$project\translations\FiddlerTexts.txt","$project\translations\FiddlerTexts.context.txt" -Destination $dict -Force
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:exe /codepage:65001 "/out:$bin\Tests.exe" /r:System.Windows.Forms.dll /r:System.Drawing.dll "/r:$bin\FiddlerChinese.dll" "/r:$FiddlerPath\Fiddler.exe" "$project\tests\Tests.cs"
if($LASTEXITCODE -ne 0){throw 'Test compilation failed.'}
& "$bin\Tests.exe" $FiddlerPath "$project\test-output"
if($LASTEXITCODE -ne 0){throw 'Tests failed.'}
# Keep installer mocks in a child process, separate from developer shell state.
& "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$project\tests\Test-Installer.ps1"
if($LASTEXITCODE -ne 0){throw 'Installer tests failed.'}
& "$PSScriptRoot\New-Release.ps1" -PluginPath "$bin\FiddlerChinese.dll"
& "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$project\tests\Test-Release.ps1"
if($LASTEXITCODE -ne 0){throw 'Release package tests failed.'}