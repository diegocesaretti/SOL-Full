# SOL-Full architecture

SOL-Full is an integration and distribution repository. It does not fork the source trees of SOL or its official plugins.

## Ownership model

Each component remains authoritative in its original repository:

- `diegocesaretti/SOL` — SOL Core and the Home Assistant SOL plugin.
- `diegocesaretti/Whatsapp-Codex-Nexo` — Nexo · WhatsApp SOL plugin.
- `diegocesaretti/Codex-audio-remote` — Codex Audio Remote SOL plugin and standalone/client development.

SOL-Full owns only the tested combination: exact release tags, release asset ids, source commits, SHA-256 digests, assembly logic, integration CI and full releases.

## Bundle layout

A generated Windows bundle has this layout:

```text
SOL-Full-Windows-<version>.zip
├─ SOL/                         # expanded SOL-Windows.zip
├─ plugins/
│  ├─ Nexo.solplugin
│  ├─ HomeAssistant.solplugin
│  └─ CodexAudioRemote.solplugin
├─ manifest/
│  └─ sol-full.json
└─ INSTALL.txt
```

Plugins are kept as SOL-native packages instead of being unpacked into the core. This preserves plugin isolation, permissions, settings and independent upgrade paths.

## Reproducibility

`manifest/sol-full.json` pins every component by:

- repository;
- release tag;
- release asset name and asset id;
- source commit;
- SHA-256 digest.

The assembler downloads the exact public release asset id and refuses to continue when its SHA-256 does not match the pinned digest. Plugin packages are additionally checked with the bundled Core's actual ZIP reader and manifest validator, including id/version, entry point, schema requirements and advertised registration APIs. SOL Core must supply `SOL/SOL.exe` and its portable Node runtime. A failure prevents bundle creation and release publication. These checks do not launch plugins or use credentials, microphones or household devices.

This means a mutable rolling tag such as `sol-plugin-latest` cannot silently change the contents of an existing SOL-Full version: changing the asset requires updating the pinned asset id and digest in this repository.

## Upgrade policy

When an upstream component changes:

1. publish the upstream release artifact in its owner repository;
2. update release tag/asset id/source commit/SHA-256 in `manifest/sol-full.json`;
3. run SOL-Full integration CI;
4. inspect the generated bundle artifact;
5. merge and publish a new `sol-full-v*` release.

The source repositories remain independent; SOL-Full should not duplicate their full source trees as an upgrade shortcut.

## Future integration

The desired long-term dependency direction is:

```text
Home Assistant ─┐
Nexo ───────────┼─> SOL Core / unified tool registry / MCP
Audio Remote ───┘
```

Where practical, cross-plugin capabilities should flow through SOL rather than plugins opening duplicate connections to each other. In particular, Codex Audio Remote's legacy/direct Home Assistant context path can eventually be replaced by SOL-provided context after feature parity is verified.
