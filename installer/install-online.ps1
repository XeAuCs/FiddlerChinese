[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
    [string]$Repository,
    [string]$FiddlerPath,
    [string]$Version
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if ($env:OS -ne 'Windows_NT' -or $PSVersionTable.PSVersion -lt [Version]'5.1') {
    throw 'This installer requires Windows and PowerShell 5.1 or later.'
}
$previousTls = [Net.ServicePointManager]::SecurityProtocol
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$stage = Join-Path $temporaryRoot ('FiddlerChinese-' + [guid]::NewGuid().ToString('N'))
$assetName = 'FiddlerChinese.zip'
try {
    [Net.ServicePointManager]::SecurityProtocol = $previousTls -bor [Net.SecurityProtocolType]::Tls12
    New-Item -ItemType Directory -Path $stage | Out-Null
    # Public asset links do not require an unauthenticated GitHub API request.
    $releasePath = 'latest/download'
    if ($Version) { $releasePath = 'download/' + [Uri]::EscapeDataString($Version) }
    $downloadBase = "https://github.com/$Repository/releases/$releasePath"
    $headers = @{'User-Agent'='FiddlerChinese-Installer'}
    Write-Output "`n正在下载安装文件，请稍候...`n"
    foreach ($name in @($assetName, "$assetName.sha256")) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri "$downloadBase/$name" -Headers $headers -OutFile (Join-Path $stage $name) -TimeoutSec 120
        } catch {
            throw "Cannot download '$name'. Check access to github.com and that the release contains this asset. No plugin files were installed. $($_.Exception.Message)"
        }
    }
    $checksum = (Get-Content -LiteralPath (Join-Path $stage "$assetName.sha256") -Raw).Trim()
    if ($checksum -notmatch '^([0-9a-fA-F]{64})\s+\*?FiddlerChinese\.zip$') { throw 'Invalid release checksum file.' }
    $expected = $Matches[1]
    $archivePath = Join-Path $stage $assetName
    if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $expected) {
        throw 'Download checksum mismatch. No plugin files were installed. Please retry, or use -Version to select a fixed release.'
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $expanded = Join-Path $stage 'package'
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName.Replace('/', '\')
            if ([IO.Path]::IsPathRooted($name) -or $name.Contains(':')) { throw 'Unsafe path in the release archive.' }
            $resolved = [IO.Path]::GetFullPath((Join-Path $expanded $name))
            if (!$resolved.StartsWith("$expanded\", [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe path in the release archive.' }
        }
    } finally { $archive.Dispose() }
    [IO.Compression.ZipFile]::ExtractToDirectory($archivePath, $expanded)
    foreach ($file in @('Install.ps1', 'Installer.Common.ps1', 'Scripts\FiddlerChinese.dll', 'Scripts\FiddlerChinese\FiddlerTexts.txt', 'Scripts\FiddlerChinese\FiddlerTexts.context.txt')) {
        if (!(Test-Path -LiteralPath (Join-Path $expanded $file) -PathType Leaf)) { throw "Incomplete release package: $file" }
    }
    $arguments = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $expanded 'Install.ps1'))
    if ($FiddlerPath) { $arguments += @('-FiddlerPath', $FiddlerPath) }
    # The execution policy override applies only to this child process.
    & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Installation did not complete. Follow the message above and run the command again.' }

} finally {
    [Net.ServicePointManager]::SecurityProtocol = $previousTls
    $cleanup = [IO.Path]::GetFullPath($stage)
    if ($cleanup.StartsWith("$temporaryRoot\FiddlerChinese-", [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $cleanup)) {
        try { Remove-Item -LiteralPath $cleanup -Recurse -Force -ErrorAction Stop }
        catch { Write-Warning "Temporary files could not be removed: $cleanup" }
    }
}
