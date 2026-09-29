param([string]$FiddlerPath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\Installer.Common.ps1"
$targetRoot=Resolve-FiddlerInstallPath $FiddlerPath
if(Get-Process -Name Fiddler -ErrorAction SilentlyContinue){throw '请先关闭 Fiddler，再重新运行安装。'}
$payload=Join-Path $PSScriptRoot 'Scripts'
$required=@('FiddlerChinese.dll','FiddlerChinese\FiddlerTexts.txt','FiddlerChinese\FiddlerTexts.context.txt')
foreach($relative in $required){
    if(!(Test-Path -LiteralPath (Join-Path $payload $relative) -PathType Leaf)){throw "安装包缺少文件：$relative"}
}
if(Test-Path -LiteralPath "$targetRoot\Scripts\FdToChinese.dll"){
    throw "检测到旧版汉化插件：$targetRoot\Scripts\FdToChinese.dll。请先手动移除旧插件，再安装新版。"
}
Write-Output ''
Write-Output 'Fiddler 中文界面'
Write-Output "安装位置：$targetRoot"
Write-Output ''
$changed=@($required | Where-Object {
    $destination=Join-Path "$targetRoot\Scripts" $_
    !(Test-Path -LiteralPath $destination -PathType Leaf) -or
        (Get-FileHash -LiteralPath $destination).Hash -ne (Get-FileHash -LiteralPath (Join-Path $payload $_)).Hash
})
try {
    if($changed.Count){
        New-Item -ItemType Directory -Path "$targetRoot\Scripts\FiddlerChinese" -Force | Out-Null
        foreach($relative in $changed){
            $destination=Join-Path "$targetRoot\Scripts" $relative
            Copy-Item -LiteralPath (Join-Path $payload $relative) -Destination $destination -Force
            if((Get-FileHash -LiteralPath $destination).Hash -ne (Get-FileHash -LiteralPath (Join-Path $payload $relative)).Hash){throw "文件校验失败：$relative"}
        }
    }
    # Remove the obsolete installation pointer; do not create history or backup records.
    $oldRecord=Join-Path $targetRoot 'Scripts\FiddlerChinese\installation.json'
    if(Test-Path -LiteralPath $oldRecord -PathType Leaf){Remove-Item -LiteralPath $oldRecord}
} catch {
    throw "安装未完成，部分文件可能已更新。请检查目录写入权限后重新运行安装。错误：$($_.Exception.Message)"
}
if($changed.Count){Write-Output '安装完成。'}else{Write-Output '已安装相同文件，无需更新。'}
Write-Output '打开 Fiddler 即可使用中文界面。'
Write-Output ''
