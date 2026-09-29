param([string]$FiddlerPath='D:\Fiddler')
$ErrorActionPreference='Stop'
& "$PSScriptRoot\build.ps1" -FiddlerPath $FiddlerPath
$bin=Join-Path $PSScriptRoot 'bin'
$dict=Join-Path $bin 'FiddlerChinese'
New-Item -ItemType Directory -Path $dict -Force | Out-Null
Copy-Item -LiteralPath "$PSScriptRoot\FiddlerTexts.txt","$PSScriptRoot\FiddlerTexts.context.txt" -Destination $dict -Force
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:exe /codepage:65001 "/out:$bin\Tests.exe" /r:System.Windows.Forms.dll /r:System.Drawing.dll "/r:$bin\FiddlerChinese.dll" "/r:$FiddlerPath\Fiddler.exe" "$PSScriptRoot\Tests.cs"
if($LASTEXITCODE -ne 0){throw 'Test compilation failed.'}
& "$bin\Tests.exe" $FiddlerPath "$PSScriptRoot\test-output"
if($LASTEXITCODE -ne 0){throw 'Tests failed.'}
