import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import test from 'node:test';

const root = new URL('../entry/src/main/ets/', import.meta.url);
const files = ['domain/Models.ets','domain/EngineConfig.ets','domain/Geo.ets',
  'domain/Engine.ets','domain/Estimate.ets','domain/RunAnalysis.ets',
  'services/map/AmapPolyline.ets','services/map/AmapWebMapProvider.ets'];
const source = files.map(p=>readFileSync(new URL(p,root),'utf8')
  .replace(/^import\s[\s\S]*?;\n/gm,'').replace(/\bexport /g,'')).join('\n');
const context=vm.createContext({Array});
vm.runInContext(stripTypeScriptTypes(source)+ '\nglobalThis.api = {AmapWebMapProvider,GeoPoint,NamedPoint,Scenario,runAnalysis,DrivingRouteResult,PassengerPathResult,RoutePoint};',context);
const {AmapWebMapProvider,GeoPoint}=context.api;
const a=new GeoPoint(108.9,34.2),b=new GeoPoint(108.95,34.2);
const line=(type,polyline)=>({type,polyline});
const trip=(duration,type)=>({duration,segments:[{bus:{buslines:[line(type,'108.9,34.2;108.95,34.2')]}}]});

test('AMap chooses a verified subway alternative for metro-first; ordinary strategy keeps fastest',async()=>{
  const p=new AmapWebMapProvider('test');
  p.getJson=async()=>({status:'1',route:{transits:[trip('300','普通公交线路'),trip('600','地铁线路')]}});
  const metro=await p.getPassengerPath('transit',a,b,'西安',true);
  assert.equal(metro.usesRail,true);assert.equal(metro.etaMin,10);
  const regular=await p.getPassengerPath('transit',a,b,'西安',false);
  assert.equal(regular.usesRail,false);assert.equal(regular.etaMin,5);
});
test('railway segments count as rail and bad durations cannot become zero-minute routes',async()=>{
  const p=new AmapWebMapProvider('test');
  p.getJson=async()=>({status:'1',route:{transits:[trip('','地铁线路'),{duration:'900',segments:[{railway:{id:'G1',polyline:'108.9,34.2;108.95,34.2'}}]}]}});
  const result=await p.getPassengerPath('transit',a,b,'西安',true);
  assert.equal(result.usesRail,true);assert.equal(result.etaMin,15);
  p.getJson=async()=>({status:'1',route:{transits:[trip('','地铁线路')]}});
  await assert.rejects(()=>p.getPassengerPath('transit',a,b,'西安',true));
});
test('station POI filter accepts real station categories and rejects malformed or unrelated POIs',async()=>{
  const p=new AmapWebMapProvider('test');
  p.getJson=async(url)=>{
    assert.match(url,/types=150500%7C150501%7C150200/);
    return {status:'1',pois:[{typecode:'150500',name:'地铁站',location:'108.9,34.2'},
      {typecode:'150200',name:'火车站',location:'108.95,34.2'},
      {typecode:'150501',name:'A口',location:'108.951,34.2'},
      {typecode:'150700',name:'公交站',location:'108.92,34.2'},
      {typecode:'150500',name:'损坏数据',location:'nan,34.2'}]};
  };
  const stations=await p.getRailStations(a,8000);
  assert.deepEqual(Array.from(stations,s=>s.name),['地铁站','火车站','A口']);
});
test('ArkTS production engine accepts station coordinates beyond road snap limit and prefers rail',async()=>{
  const {Scenario,NamedPoint,DrivingRouteResult,PassengerPathResult,RoutePoint,runAnalysis}=context.api;
  const scenario=new Scenario();scenario.driver=new NamedPoint(a.lon,a.lat);scenario.passenger=new NamedPoint(b.lon,b.lat);
  scenario.constraints.preferMetro=true;
  const station=new NamedPoint(108.946,34.2,'地铁站A口');
  const providers={
    getRailStations:async()=>[station],
    getDrivingRoute:async(from,to)=>{
      const r=new DrivingRouteResult();r.dataSource='live';r.snappedDestinationM=300;
      r.polyline=[from,to];r.route=[new RoutePoint(from,0,0),new RoutePoint(to,to.lon===b.lon?1800:600,4000)];return r;
    },
    getPassengerPath:async(mode,from,to,city,preferMetro)=>{
      assert.equal(preferMetro,true);const r=new PassengerPathResult();r.dataSource='live';
      r.etaMin=mode==='transit'?5:15;r.polyline=[from,to];r.usesRail=mode==='transit';return r;
    },
  };
  const rec=await runAnalysis(scenario,providers);
  const rail=rec.suggestions.find(s=>s.mode==='transit');
  assert.equal(rail?.recommended,true);assert.equal(rail.meetingPoint.name,'地铁站A口');
  assert.equal(rail.driverEtaMin,10);assert.equal(rail.passengerEtaMin,5);
});
