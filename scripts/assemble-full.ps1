param(
  [string]$ManifestPath = "manifest/sol-full.json",
  [string]$OutputDirectory = "dist"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-ReleaseUrl([string]$Repository, [string]$Tag, [string]$Asset) {
  return "https://github.com/$Repository/releases/download/$Tag/$Asset"
}

function Assert-Sha256([string]$Path, [string]$Expected) {
  $actual = (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
  if ($actual -ne $Expected.ToLowerInvariant()) {
    throw "SHA256 mismatch for $Path. Expected $Expected, got $actual"
  }
}

function Assert-SolPlugin([string]$Path) {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $resolved = (Resolve-Path $Path).Path
  $zip = [System.IO.Compression.ZipFile]::OpenRead($resolved)
  try {
    $pluginManifest = $zip.Entries | Where-Object { $_.FullName -eq "sol-plugin.json" } | Select-Object -First 1
    if (-not $pluginManifest) { throw "Plugin package $Path does not contain sol-plugin.json at its root" }
  }
  finally {
    $zip.Dispose()
  }
}

$manifest = Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json
$version = [string]$manifest.bundle.version
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outRoot = Join-Path $repoRoot $OutputDirectory
$workRoot = Join-Path $outRoot ".work"
$stageRoot = Join-Path $workRoot "SOL-Full-$version"
$downloadRoot = Join-Path $workRoot "downloads"

Remove-Item -Recurse -Force $workRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $stageRoot, $downloadRoot, (Join-Path $stageRoot "plugins"), (Join-Path $stageRoot "manifest") | Out-Null

foreach ($component in $manifest.components) {
  $assetPath = Join-Path $downloadRoot ([string]$component.asset)
  $url = Get-ReleaseUrl $component.repository $component.releaseTag $component.asset
  Write-Host "Downloading $($component.name): $url"
  Invoke-WebRequest -Uri $url -OutFile $assetPath -UseBasicParsing
  Assert-Sha256 $assetPath $component.sha256

  if ($component.kind -eq "core") {
    # SOL-Windows.zip already contains a top-level SOL/ directory.
    Expand-Archive -Path $assetPath -DestinationPath $stageRoot -Force
    $coreDestination = Join-Path $stageRoot ([string]$component.destination)
    $launcher = Join-Path $coreDestination "SOL.exe"
    if (-not (Test-Path $launcher)) {
      throw "SOL Core archive did not produce expected launcher: $launcher"
    }
  }
  elseif ($component.kind -eq "plugin") {
    Assert-SolPlugin $assetPath
    Copy-Item $assetPath (Join-Path $stageRoot "plugins") -Force
  }
  else {
    throw "Unknown component kind: $($component.kind)"
  }
}

Copy-Item (Join-Path $repoRoot $ManifestPath) (Join-Path $stageRoot "manifest/sol-full.json") -Force

$installText = @"
SOL-Full $version

Contenido:
- SOL Core para Windows en .\SOL\
- Plugins oficiales en .\plugins\

Plugins incluidos:
- Nexo · WhatsApp
- Home Assistant
- Codex Audio Remote

Instalacion:
1. Inicia SOL desde la carpeta SOL.
2. Completa el onboarding de SOL si corresponde.
3. En Services/Plugins instala los archivos .solplugin de la carpeta plugins.
4. Configura credenciales y permisos desde SOL. No se incluyen secretos en este bundle.

La combinacion exacta de versiones y SHA-256 esta en manifest\sol-full.json.
"@
Set-Content -Path (Join-Path $stageRoot "INSTALL.txt") -Value $installText -Encoding UTF8

New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$bundlePath = Join-Path $outRoot "SOL-Full-Windows-$version.zip"
Remove-Item -Force $bundlePath -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $stageRoot "*") -DestinationPath $bundlePath -CompressionLevel Optimal

$bundleHash = (Get-FileHash -Algorithm SHA256 -Path $bundlePath).Hash.ToLowerInvariant()
Set-Content -Path (Join-Path $outRoot "SHA256SUMS.txt") -Value "$bundleHash  $(Split-Path -Leaf $bundlePath)" -Encoding ascii

Write-Host "Created $bundlePath"
Write-Host "SHA256 $bundleHash"
