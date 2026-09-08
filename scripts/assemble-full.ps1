param(
  [string]$ManifestPath = "manifest/sol-full.json",
  [string]$InputDirectory = "dist/components",
  [string]$OutputDirectory = "dist"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

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
$inputRoot = Join-Path $repoRoot $InputDirectory
$outRoot = Join-Path $repoRoot $OutputDirectory
$workRoot = Join-Path $outRoot ".work"
$stageRoot = Join-Path $workRoot "SOL-Full-$version"

Remove-Item -Recurse -Force $workRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $stageRoot, (Join-Path $stageRoot "plugins"), (Join-Path $stageRoot "manifest") | Out-Null

$componentHashes = @()
foreach ($component in $manifest.components) {
  $assetPath = Join-Path $inputRoot ([string]$component.asset)
  if (-not (Test-Path $assetPath)) { throw "Missing built component: $assetPath" }
  $assetHash = (Get-FileHash -Algorithm SHA256 -Path $assetPath).Hash.ToLowerInvariant()
  $componentHashes += "$assetHash  components/$($component.asset)"

  if ($component.kind -eq "core") {
    # SOL-Windows.zip contains a top-level SOL/ directory.
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

La combinacion exacta de repositorios y commits fuente esta en manifest\sol-full.json.
"@
Set-Content -Path (Join-Path $stageRoot "INSTALL.txt") -Value $installText -Encoding UTF8

New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$bundlePath = Join-Path $outRoot "SOL-Full-Windows-$version.zip"
Remove-Item -Force $bundlePath -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $stageRoot "*") -DestinationPath $bundlePath -CompressionLevel Optimal

$bundleHash = (Get-FileHash -Algorithm SHA256 -Path $bundlePath).Hash.ToLowerInvariant()
$allHashes = @($componentHashes + "$bundleHash  SOL-Full-Windows-$version.zip")
Set-Content -Path (Join-Path $outRoot "SHA256SUMS.txt") -Value $allHashes -Encoding ascii

Write-Host "Created $bundlePath"
Write-Host "SHA256 $bundleHash"
