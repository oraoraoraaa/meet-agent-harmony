/** Map drawing only: all paths and ETA values are supplied by the selected plan. */
export function routeMapScript(): string {
  return `
var routeFitLines=[];
function coords(points){return (points||[]).map(function(p){return [p.lon,p.lat];});}
function routeStroke(path,color,width,dashed,z){
  if(!path||path.length<2)return;
  var opts={path:path,strokeColor:color,strokeWeight:width,strokeOpacity:1,
    lineJoin:'round',lineCap:'round',zIndex:z,strokeStyle:dashed?'dashed':'solid',strokeDasharray:[6,7]};
  var line=new AMap.Polyline(opts);map.add(line);routeFitLines.push(line);return line;
}
function trafficColor(status){return {'畅通':'#24ad78','缓行':'#f5b53d','拥堵':'#f26842','严重拥堵':'#d63e50'}[status]||'#4289e7';}
var palette=['#ee4760','#8e5bd5','#00a5ad','#e79529','#347bd6','#ce4aa2','#578c42'];
var lineColors={};var colorCount=0;
function lineColor(leg){
  var key=(leg.lineName||leg.mode).split('(')[0].split('（')[0];
  if(!lineColors[key])lineColors[key]=palette[(colorCount++)%palette.length];
  return lineColors[key];
}
function etaTag(path,value,title,color,passenger){
  if(!path||path.length<2||!isFinite(value)||value<0)return;
  var tag=document.createElement('div');
  tag.style.cssText='background:white;color:#182839;border:1px solid #dce4ed;border-radius:12px;padding:6px 10px;box-shadow:0 3px 12px #16324f30;white-space:nowrap;font:600 13px -apple-system,sans-serif;pointer-events:none;';
  var time=document.createElement('div');time.textContent=Math.round(value)+' 分钟';
  time.style.cssText='font-size:16px;font-weight:750;color:'+color;tag.appendChild(time);
  var label=document.createElement('div');label.textContent=title+(routeSource.indexOf('估算')>=0?' · 含估算':'');
  label.style.cssText='margin-top:2px;font-size:10px;color:#617083';tag.appendChild(label);
  map.add(new AMap.Marker({position:path[Math.floor((path.length-1)*(passenger ? 0.65 : 0.35))],content:tag,
    anchor:passenger?'top-left':'bottom-right',offset:new AMap.Pixel(passenger?32:-30,passenger?16:-14),zIndex:160}));
}
function stationDot(stop,color,endpoint){
  var el=document.createElement('div');
  el.style.cssText='width:'+(endpoint?6:4)+'px;height:'+(endpoint?6:4)+'px;border:2px solid '+color+';background:white;border-radius:50%;box-shadow:0 1px 3px #142c4930;';
  map.add(new AMap.Marker({position:[stop.lon,stop.lat],content:el,anchor:'center',title:stop.name,zIndex:130}));
}
if(dPoly&&dPoly.length>=2){
  routeStroke(dPoly,'#ffffff',11,false,45);
  dLine=routeStroke(dPoly,'#4289e7',7,false,46);
  driverTraffic.forEach(function(segment){routeStroke(coords(segment.polyline),trafficColor(segment.status),5,false,48);});
  etaTag(dPoly,driverEta,'驾车','#1677ed',false);
}
if(pPoly&&pPoly.length>=2){
  var hasGeometry=passengerLegs.some(function(leg){return leg.polyline&&leg.polyline.length>=2;});
  if(hasGeometry){
    passengerLegs.forEach(function(leg){
      var path=coords(leg.polyline);var walking=leg.mode==='walking';var color=walking?'#788898':lineColor(leg);
      routeStroke(path,'#ffffff',walking?7:11,walking,70);
      routeStroke(path,color,walking?4:7,walking,72);
      if(!walking)(leg.stops||[]).forEach(function(stop,i,stops){stationDot(stop,color,i===0||i===stops.length-1);});
    });
  }else{
    routeStroke(pPoly,'#ffffff',9,false,70);
    pLine=routeStroke(pPoly,passengerMode==='bicycle'?'#00a5ad':'#788898',5,true,72);
  }
  etaTag(pPoly,passengerEta,passengerMode==='transit'?'公共交通':passengerMode==='bicycle'?'骑行':'步行','#7a52bf',true);
}
`;
}
