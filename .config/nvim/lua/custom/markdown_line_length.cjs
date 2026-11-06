// Read configuration like markdownlint-cli's default --stdin invocation.
// Resolve dependencies from the installed CLI, not from this Neovim config.
const fs = require('node:fs');
const { createRequire } = require('node:module');
const { pathToFileURL } = require('node:url');

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
  let config = cliRequire('run-con')('markdownlint', {});
  for (const file of ['.markdownlint.jsonc', '.markdownlint.json', '.markdownlint.yaml', '.markdownlint.yml']) {
    try {
      fs.accessSync(file);
      config = { ...config, ...readConfig(file, parsers) };
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
  process.stdout.write(JSON.stringify({ limit: enabled ? limit : false }));
}
main().catch((error) => {
  process.stderr.write(String(error));
  process.exitCode = 1;
});
