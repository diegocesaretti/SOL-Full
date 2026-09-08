param(
  [string]$ManifestPath = "manifest/sol-full.json",
  [string]$OutputDirectory = "dist/components"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-ExitCode([string]$Step) {
  if ($LASTEXITCODE -ne 0) { throw "$Step failed with exit code $LASTEXITCODE" }
}

function Get-Component([string]$Id) {
  $component = $script:Manifest.components | Where-Object { $_.id -eq $Id } | Select-Object -First 1
  if (-not $component) { throw "Component not found in manifest: $Id" }
  return $component
}

function Clone-Pinned([object]$Component, [string]$Destination) {
  Write-Host "Cloning $($Component.repository) at $($Component.sourceCommit)"
  git clone --quiet "https://github.com/$($Component.repository).git" $Destination
  Assert-ExitCode "git clone $($Component.repository)"
  git -C $Destination checkout --quiet --detach $Component.sourceCommit
  Assert-ExitCode "git checkout $($Component.sourceCommit)"
  $actual = (git -C $Destination rev-parse HEAD).Trim()
  Assert-ExitCode "git rev-parse"
  if ($actual -ne $Component.sourceCommit) { throw "Pinned commit mismatch for $($Component.id): $actual" }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$manifestFile = Join-Path $repoRoot $ManifestPath
$script:Manifest = Get-Content -Raw -Path $manifestFile | ConvertFrom-Json
$artifactRoot = Join-Path $repoRoot $OutputDirectory
$sourceRoot = Join-Path $repoRoot "dist/.sources"

Remove-Item -Recurse -Force $artifactRoot, $sourceRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $artifactRoot, $sourceRoot | Out-Null

corepack enable
Assert-ExitCode "corepack enable"

# SOL Core + Home Assistant plugin are built from the same pinned SOL source tree.
$sol = Get-Component "sol-core"
$ha = Get-Component "home-assistant"
$solDir = Join-Path $sourceRoot "SOL"
Clone-Pinned $sol $solDir

Push-Location $solDir
try {
  pnpm install --no-frozen-lockfile
  Assert-ExitCode "SOL pnpm install"
  pnpm typecheck
  Assert-ExitCode "SOL typecheck"
  pnpm build
  Assert-ExitCode "SOL build"

  $server = "dist/windows/SOL/apps/server"
  New-Item -ItemType Directory -Force $server | Out-Null
  Copy-Item apps/server/package.json "$server/package.json" -Force
  Push-Location $server
  try {
    npm install --omit=dev --ignore-scripts --no-package-lock --no-audit --no-fund
    Assert-ExitCode "SOL production npm install"
  }
  finally { Pop-Location }

  Copy-Item apps/server/dist "$server/dist" -Recurse -Force
  New-Item -ItemType Directory -Force dist/windows/SOL/packages/database | Out-Null
  Copy-Item packages/database/migrations dist/windows/SOL/packages/database/migrations -Recurse -Force
  New-Item -ItemType Directory -Force dist/windows/SOL/runtime | Out-Null
  New-Item -ItemType Directory -Force dist/windows/SOL/scripts/windows | Out-Null
  Copy-Item (Get-Command node).Source dist/windows/SOL/runtime/node.exe
  Copy-Item scripts/windows/sol-tray.ps1 dist/windows/SOL/scripts/windows/sol-tray.ps1
  Copy-Item .env.example dist/windows/SOL/.env.example

  dotnet publish packaging/windows/SolLauncher/SolLauncher.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o dist/windows/launcher
  Assert-ExitCode "SOL launcher publish"
  Copy-Item dist/windows/launcher/SOL.exe dist/windows/SOL/SOL.exe -Force

  $solOut = Join-Path $artifactRoot $sol.asset
  Remove-Item -Force $solOut -ErrorAction SilentlyContinue
  Compress-Archive -Path dist/windows/SOL -DestinationPath $solOut -CompressionLevel Optimal

  $haOut = Join-Path $artifactRoot $ha.asset
  node scripts/pack-sol-plugin.mjs plugins/home-assistant $haOut
  Assert-ExitCode "Home Assistant plugin package"
}
finally { Pop-Location }

# Nexo · WhatsApp plugin.
$nexo = Get-Component "nexo-whatsapp"
$nexoDir = Join-Path $sourceRoot "Nexo"
Clone-Pinned $nexo $nexoDir

Push-Location $nexoDir
try {
  pnpm install --no-frozen-lockfile
  Assert-ExitCode "Nexo pnpm install"
  pnpm typecheck
  Assert-ExitCode "Nexo typecheck"
  pnpm build
  Assert-ExitCode "Nexo build"

  $stage = Join-Path $nexoDir ".solplugin-stage"
  Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path (Join-Path $stage "dist") | Out-Null
  $bundleEntry = Join-Path $stage "dist/index.js"
  $banner = 'import { createRequire as __solCreateRequire } from "node:module"; const require = __solCreateRequire(import.meta.url);'
  npx --yes esbuild@0.25.9 dist/index.js --bundle --platform=node --format=esm --target=node24 --packages=bundle "--banner:js=$banner" "--outfile=$bundleEntry"
  Assert-ExitCode "Nexo esbuild bundle"

  Copy-Item sol-plugin.json (Join-Path $stage "sol-plugin.json") -Force
  $runtimePackage = @{
    name = "nexo-solplugin-runtime"
    version = [string]$nexo.version
    private = $true
    type = "module"
  } | ConvertTo-Json
  Set-Content -Path (Join-Path $stage "package.json") -Value $runtimePackage -Encoding UTF8
  node --check $bundleEntry
  Assert-ExitCode "Nexo bundled syntax check"

  $nexoOut = Join-Path $artifactRoot $nexo.asset
  $nexoZip = "$nexoOut.zip"
  Remove-Item -Force $nexoOut, $nexoZip -ErrorAction SilentlyContinue
  Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $nexoZip -CompressionLevel Optimal
  Move-Item $nexoZip $nexoOut
}
finally { Pop-Location }

# Codex Audio Remote plugin. Reproduce the upstream isolated plugin recipe.
$audio = Get-Component "codex-audio-remote"
$audioDir = Join-Path $sourceRoot "Codex-audio-remote"
Clone-Pinned $audio $audioDir

Push-Location $audioDir
try {
  $patchSteps = @(
    "scripts/prepare-official-realtime.ps1",
    "scripts/apply-runtime-settings.ps1",
    "scripts/prepare-webrtc-media-audio.ps1",
    "scripts/instrument-webrtc-audio.ps1",
    "scripts/prepare-realtime-ha-speech.ps1",
    "scripts/prepare-realtime-lifecycle-mirrors.ps1",
    "scripts/prepare-ha-stream-direct-speech-v2.ps1",
    "scripts/fix-ha-speak-race-and-mirror-persistence.ps1",
    "scripts/fix-ha-live-mirror-runtime.ps1",
    "scripts/apply-ha-context-to-working-v3.ps1",
    "scripts/prepare-sol-plugin-mode.ps1"
  )
  foreach ($patch in $patchSteps) {
    & (Join-Path $audioDir $patch)
    if (-not $?) { throw "Audio Remote patch step failed: $patch" }
  }

  $publishDir = Join-Path $audioDir "dist/sol-plugin"
  dotnet publish windows/CodexAudioRemote.Server/CodexAudioRemote.Server.csproj -c Release -r win-x64 --self-contained false -o $publishDir
  Assert-ExitCode "Codex Audio Remote publish"
  if (-not (Test-Path (Join-Path $publishDir "CodexAudioRemote.Server.exe"))) { throw "Audio Remote executable missing" }
  if (Test-Path (Join-Path $publishDir "codex.exe")) { throw "Audio Remote package must not bundle codex.exe" }
  Copy-Item sol-plugin/sol-plugin.json (Join-Path $publishDir "sol-plugin.json") -Force

  $audioOut = Join-Path $artifactRoot $audio.asset
  $audioZip = "$audioOut.zip"
  Remove-Item -Force $audioOut, $audioZip -ErrorAction SilentlyContinue
  Compress-Archive -Path (Join-Path $publishDir "*") -DestinationPath $audioZip -CompressionLevel Optimal
  Move-Item $audioZip $audioOut
}
finally { Pop-Location }

Write-Host "Built components:"
Get-ChildItem $artifactRoot | ForEach-Object {
  $hash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash.ToLowerInvariant()
  Write-Host "  $($_.Name)  $($_.Length) bytes  sha256=$hash"
}
