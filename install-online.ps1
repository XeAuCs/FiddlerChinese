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
    $releasePath = 'latest'
    if ($Version) { $releasePath = 'tags/' + [Uri]::EscapeDataString($Version) }
    $headers = @{Accept='application/vnd.github+json'; 'User-Agent'='FiddlerChinese-Installer'}
    Write-Output "Looking up the release from $Repository..."
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "https://api.github.com/repos/$Repository/releases/$releasePath" -Headers $headers -TimeoutSec 60
        $release = $response.Content | ConvertFrom-Json
    } catch {
        throw "Cannot read the GitHub release. Check the repository name, network access and whether a public release has been published. $($_.Exception.Message)"
    }
    # Obtain both files from the same release even if a new release appears during installation.
    $assets = @($release.assets)
    $downloads = @{}
    foreach ($name in @($assetName, "$assetName.sha256")) {
        $matches = @($assets | Where-Object { $_.name -ceq $name })
        if ($matches.Count -ne 1) { throw "The release must contain the asset '$name'." }
        $url = [string]$matches[0].browser_download_url
        if (!$url.StartsWith("https://github.com/$Repository/releases/download/", [StringComparison]::OrdinalIgnoreCase)) {
            throw "Unexpected release download URL for '$name'."
        }
        $downloads[$name] = $url
    }
    Write-Output "Downloading Fiddler Chinese UI $($release.tag_name)..."
    foreach ($name in @($assetName, "$assetName.sha256")) {
        Invoke-WebRequest -UseBasicParsing -Uri $downloads[$name] -Headers $headers -OutFile (Join-Path $stage $name) -TimeoutSec 120
    }
    $checksum = (Get-Content -LiteralPath (Join-Path $stage "$assetName.sha256") -Raw).Trim()
    if ($checksum -notmatch '^([0-9a-fA-F]{64})\s+\*?FiddlerChinese\.zip$') { throw 'Invalid release checksum file.' }
    $expected = $Matches[1]
    $archivePath = Join-Path $stage $assetName
    if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $expected) {
        throw 'Download checksum mismatch. No plugin files were installed. Please retry.'
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
    Write-Output 'Installation complete. Open Fiddler Classic to use the Chinese UI.'
} finally {
    [Net.ServicePointManager]::SecurityProtocol = $previousTls
    $cleanup = [IO.Path]::GetFullPath($stage)
    if ($cleanup.StartsWith("$temporaryRoot\FiddlerChinese-", [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $cleanup)) {
        try { Remove-Item -LiteralPath $cleanup -Recurse -Force -ErrorAction Stop }
        catch { Write-Warning "Temporary files could not be removed: $cleanup" }
    }
}
