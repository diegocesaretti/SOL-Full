# SOL-Full

> La combinación fijada actualmente necesita un nuevo Core compatible. El build
> rechaza los paquetes incompatibles; ver la sección Compatibility gate.

SOL-Full es la distribución Windows probada de **SOL Core + plugins oficiales de SOL**.

Este repositorio no duplica los árboles fuente de cada proyecto. En cambio, fija artefactos de release conocidos, verifica sus SHA-256, los organiza en un único bundle y ejecuta CI de integración.

## Incluido en `0.13.0-preview.1`

| Componente | Versión / tag | Artefacto |
| --- | --- | --- |
| SOL Core | `sol-windows-preview-pr12` | `SOL-Windows.zip` |
| Nexo · WhatsApp | `0.9.0` / `nexo-solplugin-preview-pr22` | `Nexo.solplugin` |
| Home Assistant | `0.1.0` / `home-assistant-plugin-latest` | `HomeAssistant.solplugin` |
| Codex Audio Remote | `1.2.1` / `sol-plugin-latest` | `CodexAudioRemote.solplugin` |

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

## Build local

Requisitos: Windows PowerShell 7+ y acceso de red a GitHub.

```powershell
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

Los pull requests ejecutan `.github/workflows/integration.yml`: descarga exactamente los assets públicos pinneados, verifica hashes y genera el bundle completo en `windows-latest`.

Los tags `sol-full-v*` ejecutan `.github/workflows/release.yml` y publican el ZIP ensamblado junto con `SHA256SUMS.txt`.

## Repositorios fuente

- `diegocesaretti/SOL`
- `diegocesaretti/Whatsapp-Codex-Nexo`
- `diegocesaretti/Codex-audio-remote`

Ver [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) para ownership, reproducibilidad y política de upgrades.

## Compatibility gate

Assembly validates each package with the bundled Core parser and ZIP reader, checks the packaged version/id and entry point, and rejects unavailable tool-registration APIs. These are static installability checks, not end-to-end credential or hardware tests.

The current pinned Core only supports manifest v1 and lacks the legacy MCP registration API required by the bundled audio and Home Assistant packages. Assembly deliberately fails until a compatible Core release is published and its asset id, source commit and SHA-256 are pinned. See the companion SOL compatibility fix; do not bypass this gate or change plugin hashes to conceal the mismatch.
