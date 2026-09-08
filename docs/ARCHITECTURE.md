# SOL-Full architecture

SOL-Full is an integration and distribution repository. It does not fork the source trees of SOL or its official plugins.

## Ownership model

Each component remains authoritative in its original repository:

- `diegocesaretti/SOL` — SOL Core and the Home Assistant SOL plugin (private).
- `diegocesaretti/Whatsapp-Codex-Nexo` — Nexo · WhatsApp SOL plugin (private).
- `diegocesaretti/Codex-audio-remote` — Codex Audio Remote SOL plugin and standalone/client development (public).

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

## Private upstream access

SOL-Full is public while SOL and Nexo are private. GitHub's per-repository `GITHUB_TOKEN` cannot read sibling private repositories, so integration and release workflows use a separate repository secret named `SOL_FULL_UPSTREAM_TOKEN`.

That credential should be a fine-grained token with the smallest possible scope:

- repository access: only `diegocesaretti/SOL` and `diegocesaretti/Whatsapp-Codex-Nexo`;
- repository permission: `Contents: Read-only`;
- no write permissions.

The token is passed only as an environment variable while the assembler downloads private release assets. It is not committed, persisted in the manifest, copied into `SOL-Full-Windows-*.zip`, or intentionally printed to logs.

## Reproducibility

`manifest/sol-full.json` pins every component by:

- repository;
- release tag;
- release asset name and asset id;
- source commit;
- SHA-256 digest.

The assembler downloads the exact release asset id and refuses to continue when its SHA-256 does not match the pinned digest. Plugin packages are additionally checked for a root `sol-plugin.json` entry. SOL Core is expanded only if the archive produces `SOL/SOL.exe`.

This means a mutable rolling tag such as `sol-plugin-latest` cannot silently change the contents of an existing SOL-Full version: changing the asset requires updating the pinned asset id and digest in this repository.

## Upgrade policy

When an upstream component changes:

1. publish the upstream release artifact in its owner repository;
2. update release tag/asset id/source commit/SHA-256 in `manifest/sol-full.json`;
3. run SOL-Full integration CI;
4. inspect the generated bundle artifact;
5. merge and publish a new `sol-full-v*` release.

Do not copy private upstream source into this public repository as an upgrade shortcut.

## Future integration

The desired long-term dependency direction is:

```text
Home Assistant ─┐
Nexo ───────────┼─> SOL Core / unified tool registry / MCP
Audio Remote ───┘
```

Where practical, cross-plugin capabilities should flow through SOL rather than plugins opening duplicate connections to each other. In particular, Codex Audio Remote's legacy/direct Home Assistant context path can eventually be replaced by SOL-provided context after feature parity is verified.
