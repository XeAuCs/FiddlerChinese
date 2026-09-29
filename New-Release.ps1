param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'release'),
    [string]$PluginPath = (Join-Path $PSScriptRoot 'package\Scripts\FiddlerChinese.dll')
)
$ErrorActionPreference='Stop'
$files=@{
    'FiddlerChinese.dll'=$PluginPath
    'FiddlerChinese\FiddlerTexts.txt'=(Join-Path $PSScriptRoot 'FiddlerTexts.txt')
    'FiddlerChinese\FiddlerTexts.context.txt'=(Join-Path $PSScriptRoot 'FiddlerTexts.context.txt')
}
foreach($source in $files.Values){
    if(!(Test-Path -LiteralPath $source -PathType Leaf)){throw "Build or supply the release payload first: $source"}
}
$out=[IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $out -Force | Out-Null
$stage=Join-Path $out ('stage-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$stage\Scripts\FiddlerChinese" -Force | Out-Null
try {
    foreach($file in $files.Keys){Copy-Item -LiteralPath $files[$file] -Destination (Join-Path "$stage\Scripts" $file)}
    foreach($file in @('Install.ps1','Installer.Common.ps1','Restore.ps1','README.md','PUBLISH.md','VALIDATION.md','install-online.ps1')){
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $stage
    }
    # Find the double-click launcher without depending on the script source encoding.
    Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.cmd' -File | Copy-Item -Destination $stage
    $zip=Join-Path $out 'FiddlerChinese.zip'
    Compress-Archive -Path "$stage\*" -DestinationPath $zip -Force
    $hash=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText("$zip.sha256", "$hash  FiddlerChinese.zip`n", [Text.Encoding]::ASCII)
    Write-Output "Upload both release assets: $zip and $zip.sha256"
} finally {
    $cleanup=[IO.Path]::GetFullPath($stage)
    if(!$cleanup.StartsWith("$out\stage-",[StringComparison]::OrdinalIgnoreCase)){throw 'Staging path validation failed.'}
    Remove-Item -LiteralPath $cleanup -Recurse -Force
}
