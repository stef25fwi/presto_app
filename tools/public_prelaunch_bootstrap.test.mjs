import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../web/flutter_bootstrap.js', import.meta.url), 'utf8')
  .replace('{{flutter_js}}', '')
  .replace('{{flutter_build_config}}', '')
  .replace('{{flutter_service_worker_version}}', 'null');

function boot({ hostname = 'ilipresto.fr', pathname = '/', storedAccess = '1', storageBlocked = false } = {}) {
  const clicks = [];
  const loads = [];
  const storage = new Map([['ilipresto-prelaunch-access', storedAccess]]);
  const shell = {
    hidden: false,
    style: {},
    dataset: {},
    setAttribute() {},
    querySelector() {
      return { hidden: false, style: {}, addEventListener: (name, callback) => {
        if (name === 'click') clicks.push(callback);
      } };
    },
    cloneNode() { return { style: {}, dataset: {}, setAttribute() {}, remove() {} }; },
    remove() {},
  };
  const window = {
    location: { hostname, pathname, search: '?developerAccess=1' },
    sessionStorage: {
      getItem: key => storage.get(key),
      setItem: (key, value) => storage.set(key, value),
      removeItem(key) {
        if (storageBlocked) throw new Error('Storage unavailable');
        storage.delete(key);
      },
    },
    addEventListener() {},
    dispatchEvent() {},
    getComputedStyle: () => ({ padding: '0', background: 'white' }),
    setTimeout: () => 1,
    clearTimeout() {},
  };
  vm.runInNewContext(source, {
    window,
    URLSearchParams,
    document: {
      getElementById: id => id === 'prelaunch-seo-shell' ? shell : null,
      createElement: () => ({}),
      head: { appendChild() {} },
      body: { appendChild() {} },
    },
    _flutter: { loader: { load: options => loads.push(options) } },
  });
  return { window, loads, storage, clickCard: () => clicks.forEach(callback => callback()) };
}

for (const hostname of [
  'ilipresto.fr', 'www.ilipresto.fr', 'ilipresto.web.app',
  'ilipresto.firebaseapp.com', 'presto-app-74abe.web.app',
  'presto-app-74abe.firebaseapp.com',
]) {
  test(`${hostname}: repeated taps and stale session flags do not start Flutter`, () => {
    const app = boot({ hostname });
    for (let i = 0; i < 16; i += 1) app.clickCard();
    assert.equal(app.loads.length, 0);
    assert.equal(app.storage.has('ilipresto-prelaunch-access'), false);
    assert.equal(app.window.iliprestoOpenApplication, undefined);
    assert.equal(app.window.iliprestoHasPrelaunchAccess, undefined);
  });
}

test('unavailable session storage keeps public prelaunch closed', () => {
  const app = boot({ storageBlocked: true });
  for (let i = 0; i < 16; i += 1) app.clickCard();
  assert.equal(app.loads.length, 0);
});

for (const pathname of ['/mentions-legales', '/cgu']) {
  test(`${pathname}: the legal application can still initialize`, () => {
    assert.equal(boot({ pathname }).loads.length, 1);
  });
}

for (const hostname of ['localhost', 'presto-app-74abe--audit-preview.web.app']) {
  test(`${hostname}: preview application remains available`, () => {
    const { loads } = boot({ hostname });
    assert.equal(loads.length, 1);
    assert.equal(loads[0].serviceWorkerSettings, undefined);
  });
}
