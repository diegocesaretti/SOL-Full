param(
  [string]$ManifestPath = "manifest/sol-full.json",
  [string]$OutputDirectory = "dist"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$MaxPluginEntries = 2000
$MaxPluginUncompressedBytes = 128 * 1024 * 1024

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

function Read-SolPluginManifest([string]$Path) {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $resolved = (Resolve-Path $Path).Path
  $zip = [System.IO.Compression.ZipFile]::OpenRead($resolved)
  try {
    $entries = @($zip.Entries)
    if ($entries.Count -gt $MaxPluginEntries) {
      throw "Plugin package $Path contains too many files ($($entries.Count)); SOL allows at most $MaxPluginEntries ZIP entries"
    }

    [int64]$uncompressedBytes = 0
    foreach ($zipEntry in $entries) {
      $uncompressedBytes += [int64]$zipEntry.Length
    }
    if ($uncompressedBytes -gt $MaxPluginUncompressedBytes) {
      throw "Plugin package $Path expands beyond SOL's 128 MiB limit ($uncompressedBytes bytes)"
    }

    $manifestEntries = @($entries | Where-Object { $_.FullName -eq "sol-plugin.json" })
    if ($manifestEntries.Count -ne 1) {
      throw "Plugin package $Path must contain exactly one sol-plugin.json at its root; found $($manifestEntries.Count)"
    }

    Write-Host "SOL package limits OK: $Path has $($entries.Count) entries and $uncompressedBytes uncompressed bytes"
    $entry = $manifestEntries[0]
    $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8, $true)
    try {
      return ($reader.ReadToEnd() | ConvertFrom-Json)
    }
    finally {
      $reader.Dispose()
    }
  }
  finally {
    $zip.Dispose()
  }
}

function Get-PackagedHostCapabilities([string]$CoreDestination) {
  $typesPath = Join-Path $CoreDestination "apps/server/dist/modules/plugins/types.js"
  if (-not (Test-Path $typesPath)) {
    throw "Packaged SOL Core does not expose plugin host capabilities at expected path: $typesPath"
  }

  $source = Get-Content -Raw -Path $typesPath
  $match = [regex]::Match($source, 'SOL_PLUGIN_HOST_CAPABILITIES\s*=\s*\[(?<body>[\s\S]*?)\]')
  if (-not $match.Success) {
    throw "Could not read SOL_PLUGIN_HOST_CAPABILITIES from packaged SOL Core"
  }

  $capabilities = @(
    [regex]::Matches($match.Groups['body'].Value, '"(?<cap>[a-z0-9][a-z0-9._:-]*)"') |
      ForEach-Object { $_.Groups['cap'].Value } |
      Select-Object -Unique
  )
  if (-not $capabilities.Count) {
    throw "Packaged SOL Core declared no plugin host capabilities"
  }
  return $capabilities
}

function Assert-PluginHostCompatibility([string[]]$HostCapabilities, [object[]]$Plugins) {
  foreach ($plugin in $Plugins) {
    $requires = @()
    $requiresProperty = $plugin.Manifest.PSObject.Properties['requires']
    if ($null -ne $requiresProperty -and $null -ne $plugin.Manifest.requires) {
      $requires = @($plugin.Manifest.requires | ForEach-Object { [string]$_ })
    }
    $missing = @($requires | Where-Object { $_ -notin $HostCapabilities })
    if ($missing.Count) {
      throw "Plugin $($plugin.Component.name) requires host capabilities not provided by packaged SOL Core: $($missing -join ', ')"
    }
    Write-Host "Compatible: $($plugin.Component.name) requires [$($requires -join ', ')]"
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

$componentHashes = @()
$hostCapabilities = @()
$pluginManifests = @()
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
    $hostCapabilities = @(Get-PackagedHostCapabilities $coreDestination)
    Write-Host "Packaged SOL host capabilities: $($hostCapabilities -join ', ')"
  }
  elseif ($component.kind -eq "plugin") {
    $pluginManifest = Read-SolPluginManifest $assetPath
    $pluginManifests += [pscustomobject]@{ Component = $component; Manifest = $pluginManifest }
    Copy-Item $assetPath (Join-Path $stageRoot "plugins") -Force
  }
  else {
    throw "Unknown component kind: $($component.kind)"
  }
}

if (-not $hostCapabilities.Count) {
  throw "No SOL Core host capabilities were discovered"
}
Assert-PluginHostCompatibility $hostCapabilities $pluginManifests

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
3. En Sistema -> Plugins instala los archivos .solplugin de la carpeta plugins. Las conexiones instaladas tambien aparecen en Conexiones.
4. Configura credenciales y permisos desde SOL. No se incluyen secretos en este bundle.

La combinacion exacta de repositorios, releases, commits y SHA-256 esta en manifest\sol-full.json.
El ensamblado verifica los limites ZIP que aplica SOL y que todos los requires de cada plugin existan en las capacidades del SOL Core empaquetado.
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
