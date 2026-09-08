import { readFile, mkdtemp, rm, stat } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';

// Run the exact host's parser and ZIP reader; do not maintain a second schema.
export async function verifyCompatibility(coreDirectory, pluginDirectory, manifestPath) {
  const core = resolve(coreDirectory);
  const modules = join(core, 'apps/server/dist/modules/plugins');
  const host = await import(pathToFileURL(join(modules, 'types.js')).href);
  const { extractZipBuffer } = await import(pathToFileURL(join(modules, 'zip.js')).href);
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  const report = [];
  const temporary = await mkdtemp(join(resolve(pluginDirectory), '.compatibility-'));
  try {
    for (const [index, component] of manifest.components.filter(c => c.kind === 'plugin').entries()) {
      const result = { id: component.id, compatible: false };
      try {
        if (component.asset !== component.asset.split(/[\\/]/).at(-1)) throw new Error('Asset must be a file name');
        const bytes = await readFile(join(pluginDirectory, component.asset));
        if (bytes.length > 64 * 1024 * 1024) throw new Error('Package exceeds the host upload limit');
        const directory = join(temporary, String(index));
        extractZipBuffer(bytes, directory, { maxUncompressedBytes: 128 * 1024 * 1024 });
        const raw = JSON.parse(await readFile(join(directory, 'sol-plugin.json'), 'utf8'));
        result.packageVersion = raw.version;
        const plugin = host.validatePluginManifest(raw);
        if (plugin.id !== component.id) throw new Error(`Plugin id mismatch: ${plugin.id}`);
        if (plugin.version !== component.version) throw new Error(`Version mismatch: pinned ${component.version}, packaged ${plugin.version}`);
        if (!(await stat(join(directory, plugin.entry))).isFile()) throw new Error('Plugin entry is not a file');
        // v1 packages cannot declare requires, but these runtime APIs are mandatory.
        for (const permission of plugin.permissions.filter(p => ['mcp.register', 'tool.register', 'tool.execute'].includes(p))) {
          if (!host.SOL_PLUGIN_HOST_CAPABILITIES?.includes(permission)) throw new Error(`Host does not advertise ${permission}`);
        }
        result.compatible = true;
      } catch (error) { result.error = error.message; }
      report.push(result);
    }
  } finally { await rm(temporary, { recursive: true, force: true }); }
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [core, plugins, manifest] = process.argv.slice(2);
  if (!core || !plugins || !manifest) throw new Error('Usage: verify-compatibility.mjs CORE PLUGINS MANIFEST');
  const report = await verifyCompatibility(core, plugins, manifest);
  console.log(JSON.stringify(report, null, 2));
  if (report.some(result => !result.compatible)) process.exitCode = 1;
}
