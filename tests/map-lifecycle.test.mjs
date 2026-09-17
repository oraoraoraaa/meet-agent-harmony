import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import test from 'node:test';

// Exercise the actual ArkTS host methods with deterministic timers and a fake
// Web controller. This does not emulate ArkUI Prop delivery or native Web paint.
const mapRoot = new URL('../entry/src/main/ets/services/map/', import.meta.url);
const htmlSource = readFileSync(new URL('AmapMapHtml.ets', mapRoot), 'utf8');
const viewSource = readFileSync(new URL('InteractiveMapView.ets', mapRoot), 'utf8');
function plainTs(source) {
  return source.replace(/^import .*;\n/gm, '')
    .replace(/@(?:Component|State|Prop)\s*/g, '')
    .replace(/@Watch\('[^']+'\)\s*/g, '')
    .replace(/export struct /g, 'class ')
    .replace(/export /g, '');
}
function harness() {
  const jobs = new Map();
  const loads = [];
  let seq = 0;
  const context = vm.createContext({
    setTimeout(fn) { jobs.set(++seq, fn); return seq; },
    clearTimeout(id) { jobs.delete(id); },
    webview: { WebviewController: class {
      loadData(html) { loads.push(html); }
      loadUrl(url) { loads.push(url); }
    } },
  });
  // build() contains ArkUI DSL, which only the SDK compiler can validate.
  const host = viewSource.slice(0, viewSource.indexOf('  build() {')) + '}';
  vm.runInContext(stripTypeScriptTypes(plainTs(htmlSource + '\n' + host)) +
    '\nglobalThis.view = new InteractiveMapView();', context);
  const view = context.view;
  return {
    view, loads, jobs,
    attach() { view.attached = true; view.lastHtml = ''; view.scheduleReload(); },
    flush() {
      const batch = [...jobs.values()]; jobs.clear();
      for (const fn of batch) fn();
    },
  };
}

test('initial attachment and a burst of marker/token changes load only the final snapshot', () => {
  const h = harness(); h.attach();
  h.view.driverLon = 109; h.view.onMarkersChanged();
  h.view.driverLat = 35; h.view.onMarkersChanged();
  h.view.reloadToken++; h.view.onReloadTokenChanged();
  assert.equal(h.loads.length, 0);
  assert.equal(h.jobs.size, 1);
  h.flush();
  assert.equal(h.loads.length, 1);
  assert.match(h.loads[0], /109/);
  assert.match(h.loads[0], /35/);
});

test('unchanged snapshots do not reload; selected route changes do', () => {
  const h = harness(); h.attach(); h.flush();
  h.view.reloadToken++; h.view.onReloadTokenChanged(); h.flush();
  assert.equal(h.loads.length, 1);
  h.view.driverLine = [{ lon: 108, lat: 34 }, { lon: 109, lat: 35 }];
  h.view.reloadToken++; h.view.onReloadTokenChanged(); h.flush();
  assert.equal(h.loads.length, 2);
  assert.match(h.loads[1], /\[\[108,34\],\[109,35\]\]/);
});

test('leaving cancels scheduled reloads; reattachment loads again', () => {
  const h = harness(); h.attach();
  h.view.aboutToDisappear(); h.flush();
  assert.equal(h.loads.length, 0);
  h.view.onMarkersChanged(); assert.equal(h.jobs.size, 0);
  h.attach(); h.flush(); assert.equal(h.loads.length, 1);
});

test('failed loadData uses the URL fallback and failed loads remain retryable', () => {
  const h = harness();
  h.view.controller.loadData = () => { throw new Error('unsupported'); };
  h.attach(); h.flush();
  assert.match(h.loads[0], /^data:text\/html/);
  h.view.controller.loadUrl = () => { throw new Error('unavailable'); };
  h.view.driverLon++; h.view.onMarkersChanged(); h.flush();
  assert.equal(h.view.status, '地图加载失败');
  h.view.controller.loadData = html => h.loads.push(html);
  h.view.reloadToken++; h.view.onReloadTokenChanged(); h.flush();
  assert.equal(h.loads.length, 2);
});

test('generated live and offline map scripts are valid JavaScript', () => {
  const context = vm.createContext({});
  vm.runInContext(stripTypeScriptTypes(plainTs(htmlSource)) +
    '\nglobalThis.make = key => { const m = new MapViewMarkers(); m.mapWebKey = key; return buildInteractiveMapHtml(m); };', context);
  for (const key of ['', 'test-placeholder']) {
    const html = context.make(key);
    const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
    assert.doesNotThrow(() => new vm.Script(script));
    assert.match(html, /textContent=\(poi.name/);
  }
});
