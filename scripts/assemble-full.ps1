param(
  [string]$ManifestPath = "manifest/sol-full.json",
  [string]$OutputDirectory = "dist"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Download-ReleaseAsset([object]$Component, [string]$Destination) {
  $apiUrl = "https://api.github.com/repos/$($Component.repository)/releases/assets/$($Component.assetId)"
  $headers = @{
    Accept = "application/octet-stream"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent" = "SOL-Full-Assembler"
  }

  Write-Host "Downloading $($Component.asset) from $($Component.repository) release $($Component.releaseTag)"
  Invoke-WebRequest -Uri $apiUrl -OutFile $Destination -Headers $headers -MaximumRedirection 10
}

function Assert-Sha256([string]$Path, [string]$Expected) {
  $actual = (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
  if ($actual -ne $Expected.ToLowerInvariant()) {
    throw "SHA256 mismatch for $Path. Expected $Expected, got $actual"
  }
  return $actual
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

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$resolvedManifest = if ([IO.Path]::IsPathRooted($ManifestPath)) { $ManifestPath } else { Join-Path $repoRoot $ManifestPath }
$manifest = Get-Content -Raw -LiteralPath $resolvedManifest | ConvertFrom-Json
$version = [string]$manifest.bundle.version
if ($version -notmatch '^\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?$') { throw 'Invalid bundle version' }
$outRoot = Join-Path $repoRoot $OutputDirectory
$workRoot = Join-Path $outRoot ".work"
$stageRoot = Join-Path $workRoot "SOL-Full-$version"
$downloadRoot = Join-Path $workRoot "downloads"

$resolvedWork = [IO.Path]::GetFullPath($workRoot)
$resolvedOutput = [IO.Path]::GetFullPath($outRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
if (-not $resolvedWork.StartsWith($resolvedOutput + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe work directory' }
Remove-Item -LiteralPath $resolvedWork -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $stageRoot, $downloadRoot, (Join-Path $stageRoot "plugins"), (Join-Path $stageRoot "manifest") | Out-Null

$componentHashes = @()
foreach ($component in $manifest.components) {
  $assetPath = Join-Path $downloadRoot ([string]$component.asset)
  Download-ReleaseAsset $component $assetPath
  $assetHash = Assert-Sha256 $assetPath $component.sha256
  $componentHashes += "$assetHash  upstream/$($component.asset)"

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

$core = @($manifest.components | Where-Object { $_.kind -eq 'core' })
if ($core.Count -ne 1) { throw 'Expected exactly one SOL Core' }
$coreDirectory = Join-Path $stageRoot $core[0].destination
$node = Join-Path $coreDirectory 'runtime/node.exe'
if (-not (Test-Path -LiteralPath $node)) { throw 'SOL Core must include runtime/node.exe' }
& $node (Join-Path $repoRoot 'scripts/verify-compatibility.mjs') $coreDirectory (Join-Path $stageRoot 'plugins') $resolvedManifest
if ($LASTEXITCODE -ne 0) { throw 'Plugin compatibility validation failed; refusing to publish an incompatible bundle' }

Copy-Item -LiteralPath $resolvedManifest -Destination (Join-Path $stageRoot "manifest/sol-full.json") -Force

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

La combinacion exacta de repositorios, releases, commits y SHA-256 esta en manifest\sol-full.json.
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
