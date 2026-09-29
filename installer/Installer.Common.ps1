# Shared by the local installer and uninstaller. Windows PowerShell 5.1+.
function Get-FiddlerInstallCandidates {
    foreach ($key in @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )) {
        foreach ($entry in @(Get-ItemProperty -Path $key -ErrorAction SilentlyContinue)) {
            if ($entry.DisplayName -match 'Fiddler' -and $entry.DisplayName -notmatch 'Everywhere') {
                if ($entry.InstallLocation) { [string]$entry.InstallLocation }
                if ($entry.DisplayIcon -match '^"?([^"\r\n]+?\.exe)(?:"|,|$)') {
                    Split-Path -Parent $Matches[1]
                }
            }
        }
    }
    foreach ($key in @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\Fiddler.exe',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\Fiddler.exe',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\Fiddler.exe'
    )) {
        $entry = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($entry -and $entry.'(default)') { Split-Path -Parent $entry.'(default)'.Trim('"') }
    }
    foreach ($base in @($env:LOCALAPPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($base) {
            foreach ($name in @('Fiddler', 'Fiddler2', 'Fiddler Classic', 'Programs\Fiddler')) {
                Join-Path $base $name
            }
        }
    }
    # Portable installations can be detected when invoked from their directory.
    if ((Get-Location).Provider.Name -eq 'FileSystem') { (Get-Location).Path }
}

function Resolve-FiddlerInstallPath {
    param([string]$FiddlerPath)
    if ($FiddlerPath) {
        $resolved = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($FiddlerPath)).TrimEnd('\')
        if (!(Test-Path -LiteralPath (Join-Path $resolved 'Fiddler.exe') -PathType Leaf)) {
            throw "Fiddler Classic was not found at '$resolved'. Use -FiddlerPath with the folder containing Fiddler.exe."
        }
        return $resolved
    }
    $found = @(@(Get-FiddlerInstallCandidates) | ForEach-Object {
        try {
            if ($_ -and (Test-Path -LiteralPath (Join-Path $_ 'Fiddler.exe') -PathType Leaf)) {
                [IO.Path]::GetFullPath($_).TrimEnd('\')
            }
        } catch { }
    } | Sort-Object -Unique)
    if ($found.Count -eq 0) {
        throw 'Fiddler Classic was not detected. Install it first, or append -FiddlerPath "D:\YourFiddlerFolder" to the command.'
    }
    if ($found.Count -gt 1) {
        throw ("Multiple Fiddler installations were found. Choose one using -FiddlerPath: " + ($found -join '; '))
    }
    return $found[0]
}
