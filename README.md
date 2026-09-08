# SOL-Full

SOL-Full es la distribución Windows probada de **SOL Core + plugins oficiales de SOL**.

Este repositorio no duplica los árboles fuente de cada proyecto. En cambio, fija artefactos de release conocidos, verifica sus SHA-256, los organiza en un único bundle y ejecuta CI de integración.

## Incluido en `0.13.0-preview.8`

| Componente | Versión / tag | Artefacto |
| --- | --- | --- |
| SOL Core | `main@7ad239c` / `sol-windows-latest` | `SOL-Windows.zip` |
| Nexo · WhatsApp | `0.9.3` / `sol-plugin-latest` | `Nexo.solplugin` |
| Home Assistant | `0.2.0` / `home-assistant-plugin-latest` | `HomeAssistant.solplugin` |
| Codex Audio Remote | `1.3.2` / `sol-plugin-latest` | `CodexAudioRemote.solplugin` |

La combinación exacta de repositorio, release, asset id, commit fuente y SHA-256 está en [`manifest/sol-full.json`](manifest/sol-full.json).

### Fundación de plataforma

Este preview incorpora en SOL Core las capas ya mergeadas para futuras integraciones sin migrar ni alterar forzosamente Nexo, Home Assistant o Audio Remote:

- actualización persistente del Core y plugins sin reconfigurar, con rollback;
- estado portable persistente fuera del directorio de la versión;
- `connections.v1` para cuentas externas estándar;
- migrations automáticas serializadas con PostgreSQL advisory lock;
- `credentials.v1` con Vault AES-256-GCM, ciphertext en PostgreSQL/Neon y clave maestra sólo en `SOL_DATA_DIR/vault.key`.

Preview.8 agrega un hotfix para bases existentes creadas antes del ledger `schema_migrations`: si `0020_plugin_runtime_capabilities.sql` ya está materializada, SOL adopta esa migración sin recrear tablas ni tocar filas y continúa con Connections/Vault. También explicita `sslmode=verify-full` para mantener el comportamiento TLS seguro actual del driver PostgreSQL sin warnings de transición.

OAuth universal todavía no forma parte de este bundle: permanece en desarrollo hasta completar CI/revisión.

### Plugins actuales

Nexo 0.9.3 mantiene el worker Codex explícito y el empaquetado compacto compatible con los límites del host.

Home Assistant 0.2.0 conserva su contrato actual.

Codex Audio Remote 1.3.2 mantiene Realtime V3/WebRTC y delega el contexto Home Assistant a través de SOL en lugar de mantener un segundo caché HA en modo plugin.

## Bundle generado

```text
SOL-Full-Windows-0.13.0-preview.8.zip
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
dist/SOL-Full-Windows-0.13.0-preview.8.zip
dist/SHA256SUMS.txt
```

El build aborta si un asset descargado no coincide con el SHA-256 fijado, si un `.solplugin` no contiene exactamente un `sol-plugin.json` en su raíz, si supera los **2000 ZIP entries** o los **128 MiB descomprimidos** permitidos por SOL, si SOL Core no produce `SOL/SOL.exe`, o si un plugin requiere una capacidad que el SOL Core empaquetado no ofrece.

## Instalación / actualización

1. Extraé el ZIP de SOL-Full.
2. Iniciá `SOL/SOL.exe`.
3. El launcher reutiliza el estado persistente existente de SOL; no copies manualmente `.env` ni `.sol` entre versiones.
4. Para instalaciones nuevas, abrí **Sistema → Plugins** e instalá los `.solplugin` de `plugins/`.
5. Para instalaciones existentes, usá la actualización in-place de plugins cuando corresponda; settings y `plugin-data` permanecen fuera del paquete.

No se incluyen secretos de usuario en el bundle.

## CI y releases

Los pull requests ejecutan `.github/workflows/integration.yml`: descarga exactamente los assets públicos pinneados, verifica hashes, límites ZIP, compatibilidad host/plugin y genera el bundle completo en `windows-latest`.

Los tags `sol-full-v*` ejecutan `.github/workflows/release.yml` y publican el ZIP ensamblado junto con `SHA256SUMS.txt`.

## Repositorios fuente

- `diegocesaretti/SOL`
- `diegocesaretti/Whatsapp-Codex-Nexo`
- `diegocesaretti/Codex-audio-remote`

Ver [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) para ownership, reproducibilidad y política de upgrades.
