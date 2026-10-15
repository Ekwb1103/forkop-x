const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const dir = 'luci-app-forkop/htdocs/luci-static/resources/view/forkop/';

async function checkInitialRender() {
  let calls = 0;
  const scheduled = [];
  const pending = new Promise(() => {});
  const methods = new Proxy({}, { get: () => () => { calls++; return pending; } });
  const tab = new Proxy({}, { get: () => () => {} });
  const map = {
    section: () => ({}),
    render: async () => 'rendered grid',
  };
  const context = vm.createContext({
    main: { FORKOP_UCI_PACKAGE: 'forkop', injectGlobalStyles() {},
      ForkopShellMethods: methods, coreService() {} },
    form: { Map: function () { return map; } },
    ui: { changes: { forkopHoldoffConfigured: true } },
    uci: {}, view: { extend: value => value },
    window: { setTimeout: fn => scheduled.push(fn) },
    section: tab, settings: tab, dashboard: tab, monitoring: tab,
    diagnostic: tab, updates: tab, tailscale: tab,
    _: value => value, console,
  });
  const entry = vm.runInContext(`(function () { ${fs.readFileSync(dir + 'forkop.js', 'utf8')} })()`, context);
  const rendered = await Promise.race([
    entry.render(),
    new Promise((_, reject) => setTimeout(() => reject(Error('initial render waited for RPC')), 200)),
  ]);
  assert.equal(rendered, 'rendered grid');
  assert.equal(calls, 0, 'no capability probe before rendering');
  scheduled[0]();
  assert.equal(calls, 1, 'capability probe starts in background');
}

async function checkRuleEditor() {
  const source = fs.readFileSync(dir + 'section.js', 'utf8');
  const start = source.indexOf('  o.load = function (section_id)', source.indexOf('  populateActionOptionValues(o);'));
  const end = source.indexOf('\n\n  o = section.taboption', start);
  let release, probes = 0, widgets = 0;
  const ready = new Promise(resolve => { release = resolve; });
  const option = { cfgvalue: id => id, renderWidget: (...args) => { widgets++; return args.join(':'); } };
  vm.runInNewContext(source.slice(start, end), {
    o: option, populateActionOptionValues() {},
    ensureActionProvidersAvailabilityLoaded() { probes++; return ready; },
  });
  assert.equal(option.load('rule1'), 'rule1');
  assert.equal(probes, 0, 'map loading does not probe providers');
  const widget = option.renderWidget('rule1', 0, 'zapret');
  assert.equal(probes, 1);
  assert.equal(widgets, 0, 'editor waits for accurate provider choices');
  release();
  assert.equal(await widget, 'rule1:0:zapret');
}

function checkDownloadChoices() {
  const source = fs.readFileSync(dir + 'settings.js', 'utf8');
  const start = source.indexOf('function isDownloadSectionAction(');
  const end = source.indexOf('function configureDownloadViaProxyFlag(');
  const listeners = {};
  let value = 'edited-selection', choices;
  const widget = { clearChoices() {}, addChoices(keys) { choices = [...keys]; } };
  const option = {
    map: { data: { state: { values: { forkop: {
      proxy: { '.type': 'section', action: 'connection' },
      zapret: { '.type': 'section', action: 'zapret' },
    } } } } },
    value(key, label) { this.keylist.push(key); this.vallist.push(label); },
    renderWidget: () => ({ addEventListener: (event, fn) => { listeners[event] = fn; } }),
    getUIElement: () => widget,
  };
  const capabilities = { loaded: false };
  const context = vm.createContext({ UCI_PACKAGE: 'forkop', uci: { get: () => value }, _: v => v });
  vm.runInContext(source.slice(start, end), context);
  context.configureDownloadSectionOption(option, 'download_section', capabilities);
  assert.equal(option.load('settings'), value);
  assert.deepEqual([...option.keylist], ['proxy', 'zapret']);
  option.renderWidget('settings');
  capabilities.loaded = true;
  capabilities.zapretInstalled = false;
  listeners.mousedown();
  assert.deepEqual(choices, ['proxy']);
  assert.equal(option.cfgvalue('settings'), 'edited-selection', 'refresh does not rewrite selection');
}

(async () => {
  await checkInitialRender();
  await checkRuleEditor();
  checkDownloadChoices();
  console.log('Initial rendering with stalled RPC, deferred rule editor and live download choices: PASS');
})().catch(error => { console.error(error); process.exitCode = 1; });
