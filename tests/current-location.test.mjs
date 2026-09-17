import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
const base=new URL('../entry/src/main/ets/',import.meta.url);
const plain=p=>readFileSync(new URL(p,base),'utf8').replace(/^import\s[\s\S]*?;\n/gm,'').replace(/\bexport /g,'');
function harness(granted=true,fail=false) {
  let calls=0;
  const context=vm.createContext({
    abilityAccessCtrl:{createAtManager:()=>({requestPermissionsFromUser:async()=>({authResults:[granted?0:-1,-1]})})},
    geoLocationManager:{LocationRequestPriority:{FIRST_FIX:1},LocationRequestScenario:{UNSET:0},
      getCurrentLocation:async(req)=>{calls++;assert.equal(req.timeoutMs,12000);if(fail)throw Error('no fix');return {latitude:34.2,longitude:108.9};}},
    mapCommon:{CoordinateType:{WGS84:0,GCJ02:1}},
    map:{convertCoordinateSync:(from,to,point)=>{assert.equal(from,0);assert.equal(to,1);return {latitude:point.latitude+.002,longitude:point.longitude+.004};}},
  });
  vm.runInContext(stripTypeScriptTypes(['domain/Models.ets','services/location/LocationService.ets',
    'services/session/TripDraftStore.ets'].map(plain).join('\n'))+
    '\nglobalThis.api={LocationService,TripDraftStore};',context);
  return {api:context.api,calls:()=>calls};
}
test('one-shot current location accepts approximate permission and converts GPS to map coordinates',async()=>{
  const h=harness();const p=await h.api.LocationService.readOnce({});
  assert.ok(Math.abs(p.lon-108.904)<1e-9);assert.ok(Math.abs(p.lat-34.202)<1e-9);assert.equal(h.calls(),1);
});
test('denial never requests a fix or silently supplies a fabricated location',async()=>{
  const h=harness(false);await assert.rejects(()=>h.api.LocationService.readOnce({}));assert.equal(h.calls(),0);
});
test('location failure propagates so manual endpoints remain usable',async()=>{
  const h=harness(true,true);await assert.rejects(()=>h.api.LocationService.readOnce({}));
});
test('only missing endpoints inherit current location, including both-unset case',()=>{
  const {TripDraftStore:s}=harness().api;
  s.setPassenger(110,35,'乘客手动位置',true);s.fillMissingFromCurrentLocation(108.9,34.2);
  assert.equal(s.get().driverLon,108.9);assert.equal(s.get().passengerLon,110);
  s.setDriver(111,36,'司机手动位置',true);s.setPassenger(0,0,'',false);s.fillMissingFromCurrentLocation(109,34);
  assert.equal(s.get().driverLon,111);assert.equal(s.get().passengerLon,109);
  const {TripDraftStore:empty}=harness().api;empty.fillMissingFromCurrentLocation(109,34);
  assert.equal(empty.get().driverLon,109);assert.equal(empty.get().passengerLon,109);
});
