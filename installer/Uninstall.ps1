param([string]$FiddlerPath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\Installer.Common.ps1"
$targetRoot=Resolve-FiddlerInstallPath $FiddlerPath
if(Get-Process -Name Fiddler -ErrorAction SilentlyContinue){throw '请先关闭 Fiddler，再重新运行卸载。'}
$files=@('FiddlerChinese.dll','FiddlerChinese\FiddlerTexts.txt','FiddlerChinese\FiddlerTexts.context.txt','FiddlerChinese\FiddlerChinese.log','FiddlerChinese\installation.json')
foreach($relative in $files){
    $path=Join-Path "$targetRoot\Scripts" $relative
    if(Test-Path -LiteralPath $path -PathType Leaf){Remove-Item -LiteralPath $path}
}
$data=Join-Path $targetRoot 'Scripts\FiddlerChinese'
if((Test-Path -LiteralPath $data -PathType Container) -and @(Get-ChildItem -LiteralPath $data -Force).Count -eq 0){Remove-Item -LiteralPath $data}
Write-Output ''
Write-Output '汉化插件已卸载。'
Write-Output "安装位置：$targetRoot"
Write-Output ''
