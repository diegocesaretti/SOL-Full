# SOL-Full

SOL-Full es la distribución Windows probada de **SOL Core + plugins oficiales de SOL**.

Este repositorio no duplica los árboles fuente de cada proyecto. En cambio, fija artefactos de release conocidos, verifica sus SHA-256, los organiza en un único bundle y ejecuta CI de integración.

## Incluido en `0.13.0-preview.3`

| Componente | Versión / tag | Artefacto |
| --- | --- | --- |
| SOL Core | `main@24ac1fe` / `sol-windows-latest` | `SOL-Windows.zip` |
| Nexo · WhatsApp | `0.9.0` / `nexo-solplugin-preview-pr22` | `Nexo.solplugin` |
| Home Assistant | `0.2.0` / `home-assistant-plugin-latest` | `HomeAssistant.solplugin` |
| Codex Audio Remote | `1.3.0` / `sol-plugin-latest` | `CodexAudioRemote.solplugin` |

La combinación exacta de repositorio, release, asset id, commit fuente y SHA-256 está en [`manifest/sol-full.json`](manifest/sol-full.json).

### Alineación de identidad

Home Assistant y Codex Audio Remote comparten ahora el contrato de **Personas canónicas de SOL**. Una Persona representa al humano; no equivale a una cuenta/miembro con acceso y por sí sola no otorga permisos. Home Assistant puede resolver `person.*` a Personas de SOL y Audio Remote valida sus bindings de hablante contra esas Personas antes de persistirlos.

Audio Remote 1.3.0 requiere `identity.read`; por eso `preview.3` fija un SOL Core construido desde el merge que incorpora ese contrato. El assembler inspecciona las capacidades del **Core realmente empaquetado** y aborta si cualquier `requires` de un plugin no está disponible en ese host.

## Bundle generado

```text
SOL-Full-Windows-0.13.0-preview.3.zip
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
dist/SOL-Full-Windows-0.13.0-preview.3.zip
dist/SHA256SUMS.txt
```

El build aborta si un asset descargado no coincide con el SHA-256 fijado, si un `.solplugin` no contiene `sol-plugin.json` en su raíz, si SOL Core no produce `SOL/SOL.exe`, **o si un plugin requiere una capacidad que el SOL Core empaquetado no ofrece**.

## Instalación

1. Extraé el ZIP de SOL-Full.
2. Iniciá SOL desde `SOL/` y completá el onboarding si corresponde.
3. Abrí **Sistema → Plugins** (las conexiones instaladas también se descubren desde **Conexiones**).
4. Instalá los tres `.solplugin` de `plugins/`.
5. Configurá permisos y credenciales desde SOL. No se incluyen secretos de usuario en el bundle.

## CI y releases

Los pull requests ejecutan `.github/workflows/integration.yml`: descarga exactamente los assets públicos pinneados, verifica hashes, verifica compatibilidad host/plugin y genera el bundle completo en `windows-latest`.

Los tags `sol-full-v*` ejecutan `.github/workflows/release.yml` y publican el ZIP ensamblado junto con `SHA256SUMS.txt`.

## Repositorios fuente

- `diegocesaretti/SOL`
- `diegocesaretti/Whatsapp-Codex-Nexo`
- `diegocesaretti/Codex-audio-remote`

Ver [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) para ownership, reproducibilidad y política de upgrades.
