param([string]$OutputDirectory, [string]$PluginPath, [string]$FiddlerPath)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
if(!$OutputDirectory){$OutputDirectory=Join-Path $project 'release'}
# Build from source by default, so releases cannot silently use a stale checked-in DLL.
if(!$PluginPath){
    & "$PSScriptRoot\build.ps1" -FiddlerPath $FiddlerPath
    $PluginPath=Join-Path $project 'bin\FiddlerChinese.dll'
}
$files=@{
    'FiddlerChinese.dll'=$PluginPath
    'FiddlerChinese\FiddlerTexts.txt'=(Join-Path $project 'translations\FiddlerTexts.txt')
    'FiddlerChinese\FiddlerTexts.context.txt'=(Join-Path $project 'translations\FiddlerTexts.context.txt')
}
foreach($source in $files.Values){
    if(!(Test-Path -LiteralPath $source -PathType Leaf)){throw "Missing release input: $source"}
}
$out=[IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $out -Force | Out-Null
$stage=Join-Path $out ('stage-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$stage\Scripts\FiddlerChinese" -Force | Out-Null
try {
    foreach($file in $files.Keys){Copy-Item -LiteralPath $files[$file] -Destination (Join-Path "$stage\Scripts" $file)}
    foreach($file in @('Install.ps1','Installer.Common.ps1','Restore.ps1')){
        Copy-Item -LiteralPath (Join-Path "$project\installer" $file) -Destination $stage
    }
    # The distribution keeps the existing flat installer layout for compatibility.
    Get-ChildItem -LiteralPath "$project\installer" -Filter '*.cmd' -File | Copy-Item -Destination $stage
    Copy-Item -LiteralPath "$project\README.md","$project\install-online.ps1" -Destination $stage
    New-Item -ItemType Directory -Path "$stage\docs" | Out-Null
    Get-ChildItem -LiteralPath "$project\docs" -Filter '*.md' -File | Copy-Item -Destination "$stage\docs"
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