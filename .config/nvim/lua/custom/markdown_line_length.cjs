// Read configuration like markdownlint-cli's default --stdin invocation.
// Resolve dependencies from the installed CLI, not from this Neovim config.
const fs = require('node:fs');
const { createRequire } = require('node:module');
const { pathToFileURL } = require('node:url');
const path = require('node:path');

async function main() {
  const cliRequire = createRequire(fs.realpathSync(process.argv[2]));
  const { readConfig } = await import(pathToFileURL(cliRequire.resolve('markdownlint/sync')).href);
  const parsers = [
    (text) => {
      const errors = [];
      const value = cliRequire('jsonc-parser').parse(text, errors, { allowTrailingComma: true });
      if (errors.length) throw new Error('Invalid JSONC');
      return value;
    },
    (text) => cliRequire('smol-toml').parse(text),
    (text) => cliRequire('js-yaml').load(text),
  ];
  const dependencies = new Set();
  const track = (file) => {
    const absolute = path.resolve(file);
    dependencies.add(absolute);
    try { dependencies.add(fs.realpathSync(absolute)); } catch { /* May not exist yet. */ }
  };
  const trackedFs = { ...fs };
  for (const method of ['readFileSync', 'accessSync', 'statSync']) {
    trackedFs[method] = (file, ...args) => {
      track(file);
      return fs[method](file, ...args);
    };
  }

  // run-con has no filesystem injection API. Instrument only its synchronous
  // lookup, after loading its modules, and restore fs before reading markdownlint.
  // Failed probes matter too: creating an rc file must invalidate the cache.
  const runCon = cliRequire('run-con');
  const originalRead = fs.readFileSync;
  const originalStat = fs.statSync;
  let config;
  try {
    fs.readFileSync = (file, ...args) => { track(file); return originalRead(file, ...args); };
    fs.statSync = (file, ...args) => { track(file); return originalStat(file, ...args); };
    config = runCon('markdownlint', {}, {});
  } finally {
    fs.readFileSync = originalRead;
    fs.statSync = originalStat;
  }
  const candidates = ['.markdownlint.jsonc', '.markdownlint.json', '.markdownlint.yaml', '.markdownlint.yml'];
  candidates.forEach(track);
  for (const file of candidates) {
    try {
      fs.accessSync(file);
      config = { ...config, ...readConfig(file, parsers, trackedFs) };
      break;
    } catch {
      // The CLI likewise skips unreadable/invalid project configuration files.
    }
  }

  // Follow markdownlint's case-insensitive aliases and configuration order.
  const defaultEntry = Object.entries(config).find(([key]) => key.toUpperCase() === 'DEFAULT');
  let enabled = defaultEntry ? Boolean(defaultEntry[1]) : true;
  let options = {};
  for (const [key, value] of Object.entries(config)) {
    if (!['MD013', 'LINE-LENGTH', 'LINE_LENGTH'].includes(key.toUpperCase())) continue;
    enabled = Boolean(value) && (typeof value !== 'object' || value.enabled === undefined || Boolean(value.enabled));
    options = value && typeof value === 'object' ? value : {};
  }
  const limit = Number(options.line_length ?? 80);
  if (enabled && (!Number.isFinite(limit) || limit <= 0)) throw new Error('Invalid MD013 line_length');
  process.stdout.write(JSON.stringify({ limit: enabled ? limit : false, dependencies: [...dependencies] }));
}
main().catch((error) => {
  process.stderr.write(String(error));
  process.exitCode = 1;
});
