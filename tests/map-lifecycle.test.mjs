import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import test from 'node:test';

// Exercise the actual ArkTS host methods with deterministic timers and a fake
// Web controller. This does not emulate ArkUI Prop delivery or native Web paint.
const mapRoot = new URL('../entry/src/main/ets/services/map/', import.meta.url);
const htmlSource = readFileSync(new URL('RouteMapScript.ets', mapRoot), 'utf8') + '\n' + readFileSync(new URL('AmapMapHtml.ets', mapRoot), 'utf8');
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
    assert.doesNotMatch(html, /<input|PlaceSearch|fetch\(/);
    assert.match(html, /var showTraffic=1/);
  }
});

test('route renderer uses supplied traffic, distinct transit colors, walking dashes and grounded ETA tags', () => {
  const items=[];
  class Polyline { constructor(options){ this.options=options;this.kind='line'; } }
  class Marker { constructor(options){ this.options=options;this.kind='marker'; } }
  const point=(lon,lat)=>({lon,lat});
  const node=()=>({style:{cssText:''},children:[],appendChild(child){this.children.push(child);}});
  const context=vm.createContext({AMap:{Polyline,Marker,Pixel:class{}},map:{add(item){items.push(item);}},
    document:{createElement:node},dPoly:[[108,34],[109,34]],pPoly:[[109,34],[110,34]],
    driverTraffic:[{status:'拥堵',polyline:[point(108,34),point(108.5,34)]}],
    passengerLegs:[{mode:'walking',polyline:[point(109,34),point(109.1,34)]},
      {mode:'subway',lineName:'2号线',polyline:[point(109.1,34),point(109.5,34)],stops:[{lon:109.1,lat:34,name:'A站'}]},
      {mode:'bus',lineName:'15路',polyline:[point(109.5,34),point(110,34)],stops:[]}],
    driverEta:23.2,passengerEta:16,passengerMode:'transit',routeSource:'实时',dLine:null,pLine:null});
  vm.runInContext(stripTypeScriptTypes(plainTs(readFileSync(new URL('RouteMapScript.ets',mapRoot),'utf8')))+
    '\nglobalThis.draw=routeMapScript();',context);
  vm.runInContext(context.draw,context);
  const lines=items.filter(i=>i.kind==='line').map(i=>i.options);
  assert.ok(lines.some(l=>l.strokeColor==='#f26842'&&l.path[1][0]===108.5));
  assert.ok(lines.some(l=>l.strokeColor==='#788898'&&l.strokeStyle==='dashed'));
  assert.ok(lines.some(l=>l.strokeColor==='#ee4760'));
  assert.ok(lines.some(l=>l.strokeColor==='#8e5bd5'));
  const tags=items.filter(i=>i.kind==='marker').map(i=>i.options.content.children[0]?.textContent).filter(Boolean);
  assert.deepEqual(tags,['23 分钟','16 分钟']);
  assert.equal(vm.runInContext("trafficColor('未知')",context),'#4289e7');
});

test('route metadata escapes HTML delimiters before entering the map script',()=>{
  const h=harness();h.view.passengerLegs=[{lineName:'</script><script>unsafe</script>',polyline:[]}];
  h.attach();h.flush();assert.doesNotMatch(h.loads[0], /<script>unsafe/);
  assert.match(h.loads[0], /\\u003c\/script>/);
});

test('zoom scales both location pins with bounded size, readable labels and no redundant writes', () => {
  const h = harness(); h.view.mapWebKey = 'test-placeholder'; h.attach(); h.flush();
  const script = h.loads[0].match(/<script>([\s\S]*?)<\/script>/)[1];
  const fn = script.slice(script.indexOf('function updateLocationPins(){'), script.indexOf('map.on("zoomchange",updateLocationPins)'));
  let zoom = 17, writes = 0;
  const make = () => ({ style:{}, lastElementChild:{style:{}}, state:'',
    getAttribute(){return this.state;},setAttribute(_,v){this.state=v;writes++;} });
  const pins = {'driver-pin':make(),'passenger-pin':make()};
  const c=vm.createContext({map:{getZoom:()=>zoom}, document:{getElementById:id=>pins[id]}});
  vm.runInContext(fn,c);
  const update=()=>vm.runInContext('updateLocationPins()',c);
  update(); assert.equal(pins['driver-pin'].style.transform,'scale(1)');
  zoom=12;update();assert.equal(pins['driver-pin'].style.transform,'scale(0.62)');
  assert.equal(pins['passenger-pin'].style.transform,'scale(0.62)');
  assert.equal(pins['driver-pin'].lastElementChild.style.display,'block');
  assert.equal(parseFloat(pins['driver-pin'].lastElementChild.style.fontSize)*0.62,12);
  const previous=writes;update();assert.equal(writes,previous);
  zoom=3;update();assert.equal(pins['driver-pin'].style.transform,'scale(0.38)');
  assert.equal(pins['driver-pin'].lastElementChild.style.display,'none');
  zoom=20;update();assert.equal(pins['driver-pin'].style.transform,'scale(1)');
});
