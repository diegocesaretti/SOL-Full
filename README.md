# SOL-Full

SOL-Full es la distribución Windows probada de **SOL Core + plugins oficiales de SOL**.

Este repositorio no duplica los árboles fuente de cada proyecto. En cambio, fija artefactos de release conocidos, verifica sus SHA-256, los organiza en un único bundle y ejecuta CI de integración.

## Incluido en `0.13.0-preview.17`

| Componente | Versión / tag | Artefacto |
| --- | --- | --- |
| SOL Core | `main@5e8cbbf` / `sol-windows-latest` | `SOL-Core-Windows.zip` |
| Nexo · WhatsApp | `0.11.2` / `sol-plugin-latest` | `Nexo.solplugin` |
| Home Assistant | `0.3.27` / `home-assistant-plugin-latest` | `HomeAssistant.solplugin` |
| Codex Audio Remote | `1.5.2` / `sol-plugin-latest` | `CodexAudioRemote.solplugin` |

La combinación exacta de repositorio, release, asset id, commit fuente y SHA-256 está en [`manifest/sol-full.json`](manifest/sol-full.json).

### Base de datos local-first y fallback de Neon

Este preview incorpora PostgreSQL embebido persistente para SOL Full. Cuando `DATABASE_URL` apunta a Neon, SOL entra automáticamente en modo híbrido: el runtime, las migraciones y `LISTEN/NOTIFY` trabajan contra la base local; Neon queda como réplica cloud sincronizada por lotes. Si Neon está sin cuota o fuera de línea, SOL puede seguir iniciando y trabajando localmente.

La primera vez que Neon está disponible, SOL siembra la copia local desde la base cloud. Si Neon ya está caído antes de esa primera siembra, SOL usa el estado `unseeded_offline` y no sobrescribe automáticamente la base remota cuando vuelva, evitando pérdida de historial. El estado de la base local, Neon y la sincronización se expone en `/health` y `/v1/system`.

### Fundación de plataforma

Este preview incorpora en SOL Core las capas ya mergeadas para futuras integraciones sin migrar ni alterar forzosamente Nexo, Home Assistant o Audio Remote:

- actualización persistente del Core y plugins sin reconfigurar, con rollback;
- estado portable persistente fuera del directorio de la versión;
- `connections.v1` para cuentas externas estándar;
- migrations automáticas serializadas con PostgreSQL advisory lock;
- `credentials.v1` con Vault AES-256-GCM, ciphertext en PostgreSQL/Neon y clave maestra sólo en `SOL_DATA_DIR/vault.key`;
- selects dinámicos para settings de plugins: el Core puede cargar opciones desde un endpoint loopback del propio plugin y renderizarlas con la UI existente.

La actualización de bases legacy mantiene `0020_plugin_runtime_capabilities.sql` idempotente incluso si quedó parcialmente aplicada antes del ledger `schema_migrations`. Las tablas e índices existentes se conservan y sólo se crean los objetos faltantes. También se mantiene `sslmode=verify-full` explícito para el driver PostgreSQL.

OAuth universal todavía no forma parte de este bundle: permanece en desarrollo hasta completar CI/revisión.

### Plugins actuales

Nexo 0.11.2 mantiene WhatsApp como input/output de SOL, media bidireccional, historial autorizado por miembro y acceso a herramientas registradas en SOL.

Home Assistant 0.3.27 mantiene control Android TV exclusivamente mediante Home Assistant Remote, reproducción nativa de Stremio, cuenta/biblioteca de Stremio, resolución de episodios y perfiles aislados de proveedores. La clasificación distingue `kids` y `family`. El proveedor Kids/Family puede seleccionarse desde un desplegable que carga únicamente los addons con rol `stream` instalados en la cuenta Stremio vinculada: SOL guarda sólo el ID del addon y la URL privada permanece dentro del plugin.

La reproducción ahora también puede seleccionar por índice el stream exacto que SOL eligió. SOL combina el orden real de addons de la cuenta con `providerIndex`, reconstruye la fila nativa de Stremio y envía `DPAD_DOWN` la cantidad necesaria seguida de `DPAD_CENTER`, siempre mediante Home Assistant `remote.send_command`. Si se pidió o seleccionó Español/Latino y el índice no puede probarse —por ejemplo, porque un proveedor anterior falla o la fila es ambigua— el flujo falla cerrado y no confirma el primer torrent por accidente. Android TV Satellite no participa en este flujo.

Codex Audio Remote 1.5.2 mantiene Realtime/WebRTC, control de calidad de audio, reconexión de transporte y delega herramientas/contexto de SOL en lugar de mantener integraciones paralelas.

## Bundle generado

```text
SOL-Full-Windows-0.13.0-preview.17.zip
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

## Acceso web y red local

SOL Core escucha por defecto en `127.0.0.1:3000`, por lo que la interfaz web sólo es accesible desde la propia PC. Esto es intencional como configuración segura por defecto.

Para habilitar acceso desde otros dispositivos de la LAN, configurá en el `.env` persistente de SOL:

```dotenv
SOL_HOST=0.0.0.0
SOL_PORT=3000
```

Después reiniciá SOL y accedé desde otro dispositivo con la IP LAN de la PC, por ejemplo `http://192.168.1.25:3000`. También puede ser necesario permitir el puerto 3000 en Windows Firewall para redes privadas. No expongas este puerto directamente a Internet; si SOL escucha fuera de localhost, usá HTTPS y revisá autenticación/permisos.

## Build local

Requisitos: Windows PowerShell 7+ y acceso de red a GitHub.

```powershell
./scripts/assemble-full.ps1
```

Salida:

```text
dist/SOL-Full-Windows-0.13.0-preview.17.zip
dist/SHA256SUMS.txt
```

El build aborta si un asset descargado no coincide con el SHA-256 fijado, si un `.solplugin` no contiene exactamente un `sol-plugin.json` en su raíz, si supera las **2000 ZIP entries**, los **256 MiB comprimidos** o los **512 MiB descomprimidos** admitidos por el SOL Core actual, si SOL Core no produce `SOL/SOL.exe`, o si un plugin requiere una capacidad que el SOL Core empaquetado no ofrece.

## Instalación / actualización

1. Extraé el ZIP de SOL-Full.
2. Iniciá `SOL/SOL.exe`.
3. El launcher reutiliza el estado persistente existente de SOL; no copies manualmente `.env` ni `.sol` entre versiones.
4. Para instalaciones nuevas, abrí **Sistema → Plugins** e instalá los `.solplugin` de `plugins/`.
5. Para instalaciones existentes, usá la actualización in-place de plugins cuando corresponda; settings y `plugin-data` permanecen fuera del paquete.
6. Para usar el selector dinámico Kids/Family, primero guardá la cuenta Stremio vinculada; después reabrí **Configurar** y elegí el addon español/latino en el desplegable.

No se incluyen secretos de usuario en el bundle.

## CI y releases

Los pull requests ejecutan `.github/workflows/integration.yml`: descarga exactamente los assets públicos pinneados, verifica hashes, límites ZIP, compatibilidad host/plugin y genera el bundle completo en `windows-latest`.

Los tags `sol-full-v*` ejecutan `.github/workflows/release.yml` y publican el ZIP ensamblado junto con `SHA256SUMS.txt`.

## Repositorios fuente

- `diegocesaretti/SOL`
- `diegocesaretti/Whatsapp-Codex-Nexo`
- `diegocesaretti/Codex-audio-remote`

Ver [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) para ownership, reproducibilidad y política de upgrades.
