$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ($env:OS -ne 'Windows_NT') {
    throw 'scudo bootstrap only supports windows.'
}

$repoZipUrl = 'https://codeload.github.com/Microck/scudo/zip/refs/heads/main'
$installRoot = Join-Path $env:LOCALAPPDATA 'scudo'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('scudo-bootstrap-' + [guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $tempRoot 'scudo.zip'
$extractRoot = Join-Path $tempRoot 'extract'

function Remove-ScudoPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null

try {
    Invoke-WebRequest -Uri $repoZipUrl -OutFile $zipPath -UseBasicParsing
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force

    $sourceRoot = Get-ChildItem -Path $extractRoot -Directory | Select-Object -First 1
    if ($null -eq $sourceRoot) {
        throw 'failed to unpack scudo.'
    }

    Remove-ScudoPath -Path $installRoot
    New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    Copy-Item -Path (Join-Path $sourceRoot.FullName '*') -Destination $installRoot -Recurse -Force

    $launcherPath = Join-Path $installRoot 'scudo.ps1'
    if (-not (Test-Path -LiteralPath $launcherPath)) {
        throw 'scudo launcher was not installed correctly.'
    }

    Set-Location $installRoot
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcherPath --cli
}
finally {
    Remove-ScudoPath -Path $tempRoot
}
