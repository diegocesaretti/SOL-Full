# SOL-Full architecture

SOL-Full is an integration and distribution repository. It does not fork the source trees of SOL or its official plugins.

## Ownership model

Each component remains authoritative in its original repository:

- `diegocesaretti/SOL` — SOL Core and the Home Assistant SOL plugin.
- `diegocesaretti/Whatsapp-Codex-Nexo` — Nexo · WhatsApp SOL plugin.
- `diegocesaretti/Codex-audio-remote` — Codex Audio Remote SOL plugin and its standalone/client development.

SOL-Full owns only the tested combination: exact release tags, source commits, SHA-256 digests, assembly logic, integration CI and full releases.

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
- asset name;
- source commit;
- SHA-256 digest.

The assembler refuses to continue when any downloaded asset does not match its pinned digest. Plugin packages are additionally checked for a root `sol-plugin.json` entry.

## Upgrade policy

Rolling upstream tags such as `sol-plugin-latest` must never be trusted implicitly by a SOL-Full release. When an upstream asset changes, update its source commit and SHA-256 in the SOL-Full manifest through a pull request, run integration CI, then release a new SOL-Full version.

## Future integration

The desired long-term dependency direction is:

```text
Home Assistant ─┐
Nexo ───────────┼─> SOL Core / unified tool registry / MCP
Audio Remote ───┘
```

Where practical, cross-plugin capabilities should flow through SOL rather than plugins opening duplicate connections to each other. In particular, Codex Audio Remote's legacy/direct Home Assistant context path can eventually be replaced by SOL-provided context after feature parity is verified.
