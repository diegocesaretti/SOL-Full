# SOL-Full

SOL-Full es la distribución Windows probada de **SOL Core + plugins oficiales de SOL**.

Este repositorio no copia ni publica el código fuente de los proyectos privados. En cambio, fija artefactos de release conocidos, verifica sus SHA-256, los organiza en un único bundle y ejecuta CI de integración.

## Incluido en `0.13.0-preview.1`

| Componente | Versión / tag | Artefacto |
| --- | --- | --- |
| SOL Core | `sol-windows-preview-pr12` | `SOL-Windows.zip` |
| Nexo · WhatsApp | `0.9.0` / `nexo-solplugin-preview-pr22` | `Nexo.solplugin` |
| Home Assistant | `0.2.0` / `home-assistant-plugin-latest` | `HomeAssistant.solplugin` |
| Codex Audio Remote | `1.1.0` / `sol-plugin-latest` | `CodexAudioRemote.solplugin` |

La combinación exacta de repositorio, release, asset id, commit fuente y SHA-256 está en [`manifest/sol-full.json`](manifest/sol-full.json).

## Bundle generado

```text
SOL-Full-Windows-0.13.0-preview.1.zip
├─ SOL/
├─ plugins/
│  ├─ Nexo.solplugin
│  ├─ HomeAssistant.solplugin
│  └─ CodexAudioRemote.solplugin
├─ manifest/
│  └─ sol-full.json
└─ INSTALL.txt
```

SOL sigue siendo el host y la fuente de verdad. Los plugins permanecen como paquetes `.solplugin` nativos para conservar permisos, settings, lifecycle y actualizaciones independientes.

## Acceso a upstreams privados

`diegocesaretti/SOL` y `diegocesaretti/Whatsapp-Codex-Nexo` son repositorios privados. Por eso el ensamblador necesita un token GitHub de **solo lectura** que pueda leer sus releases.

Usá un fine-grained Personal Access Token con acceso únicamente a esos repositorios y permiso **Contents: Read-only**, y exponelo como:

```powershell
$env:SOL_FULL_UPSTREAM_TOKEN = "..."
```

Para GitHub Actions, guardalo como repository secret con el nombre:

```text
SOL_FULL_UPSTREAM_TOKEN
```

El token nunca se escribe en el manifest, los logs ni el bundle.

## Build local

Requisitos: Windows PowerShell 7+ y acceso de red a GitHub.

```powershell
$env:SOL_FULL_UPSTREAM_TOKEN = "<token-read-only>"
./scripts/assemble-full.ps1
```

Salida:

```text
dist/SOL-Full-Windows-0.13.0-preview.1.zip
dist/SHA256SUMS.txt
```

El build aborta si un asset descargado no coincide con el SHA-256 fijado. Cada `.solplugin` también se valida para comprobar que contiene `sol-plugin.json` en su raíz, y SOL Core debe producir `SOL/SOL.exe`.

## Instalación

1. Extraé el ZIP de SOL-Full.
2. Iniciá SOL desde `SOL/` y completá el onboarding si corresponde.
3. Abrí **Services / Plugins**.
4. Instalá los tres `.solplugin` de `plugins/`.
5. Configurá permisos y credenciales desde SOL. No se incluyen secretos de usuario en el bundle.

## CI y releases

Los pull requests ejecutan `.github/workflows/integration.yml`. El job requiere el secret `SOL_FULL_UPSTREAM_TOKEN`, descarga exactamente los assets pinneados, verifica hashes y genera el bundle completo en `windows-latest`.

Los tags `sol-full-v*` ejecutan `.github/workflows/release.yml` y publican el ZIP ensamblado junto con `SHA256SUMS.txt`.

## Repositorios fuente

- `diegocesaretti/SOL` — privado
- `diegocesaretti/Whatsapp-Codex-Nexo` — privado
- `diegocesaretti/Codex-audio-remote` — público

Ver [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) para ownership, seguridad, reproducibilidad y política de upgrades.
