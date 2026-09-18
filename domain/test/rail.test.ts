import assert from 'node:assert/strict';
import test from 'node:test';
import { addStationCandidates, rankWithMetroPreference } from '../src/engine.ts';
import { DEFAULT_ENGINE_CONFIG } from '../src/engineConfig.ts';
import { runAnalysis, runEstimateAnalysis, type AnalysisProviders } from '../src/runAnalysis.ts';
import type { Scenario, EvaluatedOption } from '../src/models.ts';

const scenario: Scenario = {driver: {lon:108.90,lat:34.24}, passenger:{lon:108.96,lat:34.24},
  city:'西安', constraints:{allowedModes:['walking','bicycle','transit'],preferMetro:true}};
const station = {lon:108.952,lat:34.24,name:'测试地铁站A口'};
function provider(): AnalysisProviders {
  return {
    getRailStations: async () => [station],
    getDrivingRoute: (from,to) => ({dataSource:'live',snappedDestinationM:300,polyline:[from,to],
      route:[{point:from,driverSecs:0,metersFromStart:0},
        {point:to,driverSecs:to.lon===station.lon?600:1800,metersFromStart:4000}]}),
    getPassengerPath: (mode,from,to,_city,preferMetro) => {
      assert.equal(preferMetro,true);
      return {dataSource:'live',etaMin:mode==='transit'?5:15,polyline:[from,to],usesRail:mode==='transit'};
    },
  };
}
test('station under transit minimum and outside road snap limit is accepted with routed numbers',async()=>{
  const result = await runAnalysis(scenario,provider());
  const rail = result.suggestions.find(s=>s.mode==='transit');
  assert.ok(rail?.recommended);
  assert.deepEqual(rail.meetingPoint, {...station,address:undefined});
  assert.equal(rail.driverEtaMin,10);
  assert.equal(rail.passengerEtaMin,5);
  assert.equal(result.suggestions.filter(s=>s.recommended).length,1);
});
test('avoid public transport overrides metro preference and skips station search',async()=>{
  let searches=0;
  const p=provider();p.getRailStations=async()=>{searches++;return [station];};
  const result=await runAnalysis({...scenario,constraints:{allowedModes:['walking'],avoidTransit:true,preferMetro:true}},p);
  assert.equal(result.suggestions.some(s=>s.mode==='transit'),false);
  assert.equal(searches,0);
});
test('station candidates are unique and total route fan-out stays bounded',()=>{
  const stations=Array.from({length:20},(_,i)=>({...station,lon:station.lon+i*.005}));
  const result=addStationCandidates([], [...stations,station],scenario.driver,scenario.passenger,true);
  assert.equal(result.length,DEFAULT_ENGINE_CONFIG.maxCandidates);
  assert.equal(new Set(result.map(c=>c.point.lon)).size,result.length);
});
test('metro preference favors verified rail without violating stay-put threshold',()=>{
  const common={meetingPoint:station,routeIndex:0,driverEtaMin:5,passengerEtaMin:5,completionMin:5};
  const walk:EvaluatedOption={...common,mode:'walking',score:6};
  const rail:EvaluatedOption={...common,mode:'transit',score:10,usesRail:true};
  assert.equal(rankWithMetroPreference([walk,rail],20,true)[0],rail);
  assert.equal(rankWithMetroPreference([walk,rail],11,true)[0],walk);
  assert.equal(rankWithMetroPreference([walk,rail],20,false)[0],walk);
});
test('station search failure preserves offline planning and never invents stations',async()=>{
  const offline=await runEstimateAnalysis(scenario);
  assert.equal(offline.dataSource,'estimate');
  assert.equal(offline.suggestions.some(s=>s.meetingPoint.name?.includes('地铁站')),false);
  const p=provider();p.getRailStations=async()=>{throw new Error('offline');};
  const result=await runAnalysis(scenario,p);
  assert.equal(result.stayPut.recommended,true);
});
test('station path fallback is labeled and does not masquerade as verified rail',async()=>{
  const p=provider();p.getPassengerPath=(mode,from,to)=>({etaMin:6,polyline:[from,to],dataSource:'live_with_fallback',usesRail:false});
  const result=await runAnalysis(scenario,p);
  assert.equal(result.dataSource,'live_with_fallback');
  assert.ok(result.suggestions.find(s=>s.mode==='transit'));
});

test('passenger itinerary flows from selected provider route to recommendation without aliasing instructions',async()=>{
  const p=provider();const instructions=['步行至地铁站'];
  p.getPassengerPath=(mode,from,to)=>({etaMin:5,polyline:[from,to],dataSource:'live',usesRail:mode==='transit',
    legs:[{mode:'walking',lineName:'',fromName:'',toName:'',durationMin:2,distanceM:120,
      stopCount:-1,entrance:'A口',exit:'',serviceHours:'',instructions}]});
  const rec=await runAnalysis(scenario,p);instructions[0]='mutated';
  assert.equal(rec.suggestions.find(s=>s.mode==='transit')?.passengerLegs?.[0]?.instructions[0],'步行至地铁站');
});

test('traffic belongs to each routed destination and estimates never inherit baseline traffic',async()=>{
  const p=provider();const original=p.getDrivingRoute;
  p.getDrivingRoute=async(from,to)=>({...await original(from,to),traffic:[{
    status:to.lon===station.lon?'拥堵':'畅通',polyline:[{...from},{...to}]}]});
  const rec=await runAnalysis(scenario,p);
  assert.equal(rec.stayPut.driverTraffic?.[0]?.status,'畅通');
  const rail=rec.suggestions.find(s=>s.mode==='transit');
  assert.equal(rail?.driverTraffic?.[0]?.status,'拥堵');
  assert.equal(rail?.driverTraffic?.[0]?.polyline.at(-1)?.lon,station.lon);
  const estimate=await runEstimateAnalysis(scenario);
  assert.equal(estimate.stayPut.driverTraffic?.length??0,0);
  assert.ok(estimate.suggestions.every(s=>(s.driverTraffic?.length??0)===0));
});
