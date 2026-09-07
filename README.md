# SOL-Full

SOL-Full is the tested Windows distribution of **SOL Core + official SOL plugins**.

Instead of copying and diverging the source of each project, this repository pins known-good release artifacts, verifies their hashes, assembles them into one organized bundle and runs integration CI.

## Included in `0.13.0-preview.1`

| Component | Version / tag | Artifact |
| --- | --- | --- |
| SOL Core | `sol-windows-preview-pr12` | `SOL-Windows.zip` |
| Nexo · WhatsApp | `0.9.0` / `nexo-solplugin-preview-pr22` | `Nexo.solplugin` |
| Home Assistant | `0.2.0` / `home-assistant-plugin-latest` | `HomeAssistant.solplugin` |
| Codex Audio Remote | `1.1.0` / `sol-plugin-latest` | `CodexAudioRemote.solplugin` |

The exact source commits and SHA-256 digests live in [`manifest/sol-full.json`](manifest/sol-full.json).

## Generated bundle

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

SOL remains the host and source of truth. Plugins remain native `.solplugin` packages so SOL can manage their permissions, settings, lifecycle and independent updates.

## Build locally

Requirements: Windows PowerShell 7+ with internet access.

```powershell
./scripts/assemble-full.ps1
```

Output:

```text
dist/SOL-Full-Windows-0.13.0-preview.1.zip
dist/SHA256SUMS.txt
```

The build aborts if an upstream artifact does not match the SHA-256 pinned in the manifest. Every plugin package is also checked for a root `sol-plugin.json`.

## Install

1. Extract the generated SOL-Full ZIP.
2. Start SOL from `SOL/` and complete onboarding if needed.
3. Open **Services / Plugins** in SOL.
4. Install the three `.solplugin` files from `plugins/`.
5. Configure each plugin from SOL. Secrets and user credentials are intentionally not bundled.

## Release flow

Pull requests run `.github/workflows/integration.yml`, which assembles the complete pinned bundle on `windows-latest` and uploads it as a CI artifact.

Tags matching `sol-full-v*` run `.github/workflows/release.yml` and publish the assembled ZIP plus `SHA256SUMS.txt` as a GitHub release.

## Source repositories

- `diegocesaretti/SOL`
- `diegocesaretti/Whatsapp-Codex-Nexo`
- `diegocesaretti/Codex-audio-remote`

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for ownership, reproducibility and upgrade rules.
