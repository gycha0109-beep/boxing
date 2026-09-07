param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,
    [switch]$CommitAndPush
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$expectedBranch = "feat/commercial-visual-integration-v0.7"
$currentBranch = (git branch --show-current).Trim()
if ($currentBranch -ne $expectedBranch) {
    throw "Checkout '$expectedBranch' before importing assets. Current branch: '$currentBranch'"
}

$zip = (Resolve-Path $ZipPath).Path
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("twelve-count-v07-" + [guid]::NewGuid())
$target = Join-Path $RepoRoot "assets\visual\v0.7"

try {
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    Expand-Archive -Path $zip -DestinationPath $temp -Force

    $source = Join-Path $temp "twelve-count-visual-assets-v0.7"
    if (-not (Test-Path $source)) {
        $directories = Get-ChildItem -Path $temp -Directory
        if ($directories.Count -eq 1) {
            $source = $directories[0].FullName
        } else {
            throw "Could not locate the asset-pack root inside ZIP."
        }
    }

    if (Test-Path $target) {
        Remove-Item -Recurse -Force $target
    }
    New-Item -ItemType Directory -Force -Path $target | Out-Null

    foreach ($folder in @("fighters", "portraits", "arena", "fx", "ui", "icons")) {
        $from = Join-Path $source $folder
        if (Test-Path $from) {
            Copy-Item -Recurse -Force $from (Join-Path $target $folder)
        }
    }
    foreach ($file in @("manifest.json", "godot_asset_mapping.json", "README.txt")) {
        $from = Join-Path $source $file
        if (Test-Path $from) {
            Copy-Item -Force $from (Join-Path $target $file)
        }
    }

    python tools/validate_visual_assets_v07.py --strict
    if ($LASTEXITCODE -ne 0) {
        throw "Visual asset validation failed."
    }

    Write-Host "v0.7 assets imported to assets/visual/v0.7" -ForegroundColor Green

    if ($CommitAndPush) {
        git add assets/visual/v0.7
        git commit -m "assets: add commercial visual pack v0.7"
        if ($LASTEXITCODE -ne 0) {
            throw "git commit failed"
        }
        git push origin $expectedBranch
        if ($LASTEXITCODE -ne 0) {
            throw "git push failed"
        }
        Write-Host "Committed and pushed v0.7 assets." -ForegroundColor Green
    }
}
finally {
    if (Test-Path $temp) {
        Remove-Item -Recurse -Force $temp
    }
}
