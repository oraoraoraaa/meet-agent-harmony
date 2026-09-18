import { routeMapScript } from './RouteMapScript';
/**
 * Build self-contained HTML for interactive AMap JS map (GCJ-02).
 * Key injected at runtime from preferences — never commit real keys.
 * Picks: meetagent://pick?role=driver|passenger&lon=&lat=&name=
 *
 * Features vs prototype:
 *  - live traffic layer (AMap.TileLayer.Traffic)
 *  - dual role: 司机起点 / 乘客位置 (tap + search both)
 *  - drag/zoom and recenter; search lives in the native endpoint sheet
 */

export class MapViewMarkers {
  driverTrafficJson: string = '[]';
  passengerLegsJson: string = '[]';
  driverEtaMin: number = -1;
  passengerEtaMin: number = -1;
  passengerMode: string = '';
  routeSource: string = '';
  driverLon: number = 0;
  driverLat: number = 0;
  hasDriver: boolean = false;
  passengerLon: number = 0;
  passengerLat: number = 0;
  hasPassenger: boolean = false;
  centerLon: number = 108.94;
  centerLat: number = 34.25;
  zoom: number = 13;
  /** Initial pick target: passenger | driver | none */
  pickRole: string = 'passenger';
  mapWebKey: string = '';
  driverPolyJson: string = '[]';
  passengerPolyJson: string = '[]';
  title: string = '地图';
  /** Show live road traffic when JS Key allows. */
  showTraffic: boolean = true;
  /** Allow in-map chips to switch driver/passenger pick (home). */
  allowRoleSwitch: boolean = true;
  /**
   * Home: 路况/居中 controls; endpoint search is native.
   * Result/preview: false — pan/zoom only, no POI pick UI.
   */
  showChrome: boolean = true;
}

function escJs(s: string): string {
  let out: string = '';
  for (let i = 0; i < s.length; i++) {
    const ch: string = s.charAt(i);
    const code: number = s.charCodeAt(i);
    if (ch === '\\') {
      out += '\\\\';
    } else if (ch === '\'') {
      out += '\\\'';
    } else if (ch === '"') {
      out += '\\"';
    } else if (ch === '\n') {
      out += '\\n';
    } else if (ch === '\r') {
      out += '\\r';
    } else if (ch === '<') {
      out += '\\u003c';
    } else if (code < 0x20) {
      // skip
    } else {
      out += ch;
    }
  }
  return out;
}

export function buildInteractiveMapHtml(m: MapViewMarkers): string {
  const key: string = m.mapWebKey.trim();
  const hasKey: boolean = key.length > 0;
  const title: string = escJs(m.title);
  const keyEsc: string = escJs(key);
  let pickRole: string = m.pickRole;
  if (pickRole !== 'driver' && pickRole !== 'passenger' && pickRole !== 'none') {
    pickRole = 'passenger';
  }
  const pickEsc: string = escJs(pickRole);
  const dLon: number = m.hasDriver ? m.driverLon : m.centerLon;
  const dLat: number = m.hasDriver ? m.driverLat : m.centerLat;
  const pLon: number = m.hasPassenger ? m.passengerLon : m.centerLon;
  const pLat: number = m.hasPassenger ? m.passengerLat : m.centerLat;
  const hasD: number = m.hasDriver ? 1 : 0;
  const hasP: number = m.hasPassenger ? 1 : 0;
  const cLon: number = m.centerLon;
  const cLat: number = m.centerLat;
  const zoom: number = m.zoom > 0 ? m.zoom : 13;
  const driverPoly: string = m.driverPolyJson.length > 0 ? m.driverPolyJson : '[]';
  const passengerPoly: string = m.passengerPolyJson.length > 0 ? m.passengerPolyJson : '[]';
  const showTraffic: number = m.showTraffic ? 1 : 0;
  const allowSwitch: number = m.allowRoleSwitch && pickRole !== 'none' ? 1 : 0;
  // Result maps: no search/traffic/center bar; still pan + pinch.
  const showChrome: number = m.showChrome ? 1 : 0;

  const html: string =
    '<!DOCTYPE html><html><head><meta charset="utf-8"/>' +
    '<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"/>' +
    '<style>' +
    'html,body,#map{margin:0;padding:0;width:100%;height:100%;background:#e8eef5;}' +
    '.amap-tile{filter:saturate(.65);}' +
    'body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;overflow:hidden;}' +
    '#top{position:absolute;left:16px;right:16px;top:16px;z-index:30;}' +
    'button{font-family:inherit;cursor:pointer;}' +
    '#btnMe,#btnTr{position:absolute;right:0;top:0;width:46px;height:46px;border:0;border-radius:15px;background:#ffffffed;color:#007aff;box-shadow:0 3px 14px #182d4218;font-size:12px;font-weight:600;}' +
    '#btnMe{top:54px;}#btnTr.off{color:#636366;}' +
    '#hint{position:absolute;left:16px;right:74px;bottom:28px;z-index:30;color:#636366;font-size:11px;background:#ffffffeb;padding:9px 12px;border-radius:12px;line-height:1.4;pointer-events:none;box-shadow:0 2px 12px #182d420a;}' +
    (showChrome ? '' : '#top,#hint{display:none!important;}') +
    '</style>' +
    (hasKey
      ? '<script src="https://webapi.amap.com/maps?v=2.0&key=' + keyEsc + '"></script>'
      : '') +
    '</head><body>' +
    '<div id="top">' +
    '<button id="btnTr" type="button" class="">路况</button>' +
    '<button id="btnMe" type="button">居中</button>' +
    '</div>' +
    '<div id="map"></div>' +
    '<div id="hint">' + title + '</div>' +
    '<script>' +
    '(function(){' +
    'var KEY="' + keyEsc + '";' +
    'var PICK="' + pickEsc + '";' +
    'var hasD=' + hasD + ',hasP=' + hasP + ';' +
    'var dLon=' + dLon + ',dLat=' + dLat + ',pLon=' + pLon + ',pLat=' + pLat + ';' +
    'var cLon=' + cLon + ',cLat=' + cLat + ',zoom=' + zoom + ';' +
    'var dPoly=' + driverPoly + ';' +
    'var pPoly=' + passengerPoly + ';' +
    'var driverTraffic=' + m.driverTrafficJson + ',passengerLegs=' + m.passengerLegsJson + ';' +
    'var driverEta=' + m.driverEtaMin + ',passengerEta=' + m.passengerEtaMin + ';' +
    'var passengerMode="' + escJs(m.passengerMode) + '",routeSource="' + escJs(m.routeSource) + '";' +
    'var showTraffic=' + showTraffic + ';' +
    'var allowSwitch=' + allowSwitch + ';' +
    'var showChrome=' + showChrome + ';' +
    'var trafficOn=!!showTraffic;' +
    'function setHint(t){ var h=document.getElementById("hint"); if(h) h.textContent=t; }' +
    'function sendChoose(lon,lat,name){' +
    '  if(PICK==="none") return;' +
    '  var u="meetagent://choose?lon="+encodeURIComponent(String(lon))' +
    '    +"&lat="+encodeURIComponent(String(lat))' +
    '    +"&name="+encodeURIComponent(name||"");' +
    '  try{ window.location.href=u; }catch(e){}' +
    '}' +
    // —— no key: schematic ——
    'if(!KEY || typeof AMap==="undefined"){' +
    '  var mapEl=document.getElementById("map");' +
    '  mapEl.style.background="linear-gradient(160deg,#e8eef5,#d6e0ec)";' +
    '  var canvas=document.createElement("canvas");' +
    '  canvas.style.width="100%";canvas.style.height="100%"; mapEl.appendChild(canvas);' +
    '  var W=0,H=0,scale=12000,ox=cLon,oy=cLat;' +
    '  function resize(){ W=mapEl.clientWidth; H=mapEl.clientHeight;' +
    '    canvas.width=W*devicePixelRatio; canvas.height=H*devicePixelRatio;' +
    '    canvas.style.width=W+"px"; canvas.style.height=H+"px"; var pts=[]; if(hasD)pts.push([dLon,dLat]);if(hasP)pts.push([pLon,pLat]);pts=pts.concat(dPoly,pPoly); if(pts.length>1){var xs=pts.map(function(p){return p[0];}),ys=pts.map(function(p){return p[1];});var x0=Math.min.apply(null,xs),x1=Math.max.apply(null,xs),y0=Math.min.apply(null,ys),y1=Math.max.apply(null,ys);ox=(x0+x1)/2;oy=(y0+y1)/2;scale=Math.min((W-100)/Math.max(.002,x1-x0),(H-160)/Math.max(.002,y1-y0));} draw(); }' +
    '  function proj(lon,lat){ return {x:(lon-ox)*scale+W/2, y:(oy-lat)*scale+H/2}; }' +
    '  function unproj(x,y){ return {lon:(x-W/2)/scale+ox, lat:oy-(y-H/2)/scale}; }' +
    '  function draw(){ var ctx=canvas.getContext("2d"); if(!ctx) return;' +
    '    ctx.setTransform(devicePixelRatio,0,0,devicePixelRatio,0,0); ctx.clearRect(0,0,W,H);' +
    '    ctx.strokeStyle="rgba(0,0,0,.06)";' +
    '    for(var i=0;i<12;i++){ ctx.beginPath(); ctx.moveTo(i*W/12,0); ctx.lineTo(i*W/12,H); ctx.stroke();' +
    '      ctx.beginPath(); ctx.moveTo(0,i*H/12); ctx.lineTo(W,i*H/12); ctx.stroke(); }' +
    '    function line(poly,color){ if(!poly||poly.length<2) return; ctx.strokeStyle=color; ctx.lineWidth=3; ctx.beginPath();' +
    '      for(var i=0;i<poly.length;i++){ var p=proj(poly[i][0],poly[i][1]); if(i===0) ctx.moveTo(p.x,p.y); else ctx.lineTo(p.x,p.y);} ctx.stroke(); }' +
    '    line(dPoly,"#0A84FF"); line(pPoly,"#34C759");' +
    '    function mark(lon,lat,color,label){ var p=proj(lon,lat); ctx.fillStyle=color; ctx.beginPath(); ctx.arc(p.x,p.y,8,0,Math.PI*2); ctx.fill();' +
    '      ctx.strokeStyle="#fff";ctx.lineWidth=3;ctx.stroke();ctx.fillStyle="#3a3a3c"; ctx.font="12px sans-serif"; ctx.fillText(label,p.x+10,p.y+3); }' +
    '    if(hasD) mark(dLon,dLat,"#0A84FF","司"); if(hasP) mark(pLon,pLat,"#34C759","乘"); }' +
    '  var dragging=false,lx=0,ly=0;' +
    '  canvas.addEventListener("touchstart",function(e){ dragging=true; lx=e.touches[0].clientX; ly=e.touches[0].clientY; });' +
    '  canvas.addEventListener("touchmove",function(e){ if(!dragging) return; var x=e.touches[0].clientX,y=e.touches[0].clientY;' +
    '    ox-=(x-lx)/scale; oy+=(y-ly)/scale; lx=x; ly=y; draw(); e.preventDefault(); },{passive:false});' +
    '  canvas.addEventListener("touchend",function(){ dragging=false; });' +
    '  canvas.addEventListener("click",function(e){ if(PICK==="none"||!showChrome) return; var r=canvas.getBoundingClientRect();' +
    '    var p=unproj(e.clientX-r.left,e.clientY-r.top);' +
    '    sendChoose(p.lon,p.lat,"地图选点"); setHint("已选地点，请选择用途"); });' +
    '  var elMe=document.getElementById("btnMe"); if(elMe) elMe.onclick=function(){ ox=cLon; oy=cLat; draw(); };' +
    '  var elTr=document.getElementById("btnTr"); if(elTr) elTr.onclick=function(){ setHint("离线状态暂不支持路况"); };' +
    '  window.addEventListener("resize",resize); resize();' +
    '  if(showChrome) setHint("离线示意 · 不含道路信息，仅供位置参考"); return;' +
    '}' +
    // —— AMap live ——
    'var map=new AMap.Map("map",{zoom:zoom,center:[cLon,cLat],viewMode:"2D",' +
    '  mapStyle:"amap://styles/fresh",showBuildingBlock:true,features:["bg","road","building","point"]});' +
    'var trafficLayer=null;' +
    'function applyTraffic(on){' +
    '  trafficOn=!!on;' +
    '  var b=document.getElementById("btnTr");' +
    '  if(b){ b.className=trafficOn?"":"off"; b.textContent=trafficOn?"路况":"路况"; }' +
    '  try{' +
    '    if(trafficOn){' +
    '      if(!trafficLayer){ trafficLayer=new AMap.TileLayer.Traffic({zIndex:10,autoRefresh:true,interval:180}); }' +
    '      map.add(trafficLayer);' +
    '      setHint("已显示实时路况");' +
    '    } else if(trafficLayer){ map.remove(trafficLayer); setHint("轻点地图选点，或点下方位置搜索"); }' +
    '  }catch(e){ setHint("路况暂不可用，请稍后重试"); }' +
    '}' +
    'var dMarker=null,pMarker=null,dLine=null,pLine=null;' +
    "function locationPin(color,label){" +
    "  return '<div style=\"width:100px;text-align:center;pointer-events:none\"><div style=\"position:relative;margin:auto;width:42px;height:42px;border-radius:50%;background:linear-gradient(155deg,#ffffff88,transparent 65%),'+color+';border:3px solid #233347;box-shadow:0 3px 8px #0005\"><span style=\"display:block;margin:10px auto 0;width:11px;height:11px;border-radius:50%;background:#172639\"></span><span style=\"display:block;margin:2px auto;width:4px;height:12px;border-radius:2px;background:#172639\"></span></div><div style=\"margin:-1px auto 0;width:0;height:0;border-left:7px solid transparent;border-right:7px solid transparent;border-top:9px solid #233347\"></div><div style=\"margin:3px auto 4px;width:8px;height:8px;border:2px solid white;border-radius:50%;background:'+color+';box-shadow:0 1px 4px #0005\"></div><div style=\"font:600 12px sans-serif;color:#172639;text-shadow:0 1px 2px white,0 -1px 2px white,1px 0 2px white,-1px 0 2px white;white-space:nowrap\">'+label+'</div></div>';" +
    "}" +
    'function ensureDriver(lon,lat,name){' +
    '  if(dMarker){ dMarker.setPosition([lon,lat]); if(name) dMarker.setTitle(name); }' +
    '  else { dMarker=new AMap.Marker({position:[lon,lat],title:name||"司机",' +
    '    content:locationPin("#459CFF","司机位置"),' +
    '    offset:new AMap.Pixel(-50,-66),zIndex:150}); map.add(dMarker); }' +
    '  dLon=lon; dLat=lat; hasD=1;' +
    '}' +
    'function ensurePassenger(lon,lat,name){' +
    '  if(pMarker){ pMarker.setPosition([lon,lat]); if(name) pMarker.setTitle(name); }' +
    '  else { pMarker=new AMap.Marker({position:[lon,lat],title:name||"乘客",' +
    '    content:locationPin("#F47787","乘客位置"),' +
    '    offset:new AMap.Pixel(-50,-66),zIndex:150}); map.add(pMarker); }' +
    '  pLon=lon; pLat=lat; hasP=1;' +
    '}' +
    'function clearDriver(){ if(dMarker){ map.remove(dMarker); dMarker=null; } hasD=0; }' +
    'function clearPassenger(){ if(pMarker){ map.remove(pMarker); pMarker=null; } hasP=0; }' +
    // Host (ArkTS) calls this after assign so pins move without full reload
    'window.meetagentSetMarkers=function(ddLon,ddLat,hD,ppLon,ppLat,hP,focus){' +
    '  try{' +
    '    if(hD){ ensureDriver(ddLon,ddLat,"司机"); } else { clearDriver(); }' +
    '    if(hP){ ensurePassenger(ppLon,ppLat,"乘客"); } else { clearPassenger(); }' +
    '    var fit=[]; if(hD) fit.push([ddLon,ddLat]); if(hP) fit.push([ppLon,ppLat]);' +
    '    if(focus && fit.length===1){ map.setZoomAndCenter(Math.max(map.getZoom(),15), fit[0]); }' +
    '    else if(fit.length>=2){ map.setFitView(null,false,[60,60,60,60]); }' +
    '    else if(fit.length===1){ map.setCenter(fit[0]); }' +
    '    setHint("位置已更新");' +
    '  }catch(e){ setHint("暂时无法更新位置"); }' +
    '};' +
    'if(hasD) ensureDriver(dLon,dLat,"司机"); if(hasP) ensurePassenger(pLon,pLat,"乘客");' +
    routeMapScript() +
    'try{ var fit=[]; if(hasD) fit.push([dLon,dLat]); if(hasP) fit.push([pLon,pLat]);' +
    '  if(dPoly) dPoly.forEach(function(x){fit.push([x[0],x[1]]);});' +
    '  if(pPoly) pPoly.forEach(function(x){fit.push([x[0],x[1]]);});' +
    '  if(fit.length>=2) map.setFitView(routeFitLines.length>0?routeFitLines:null,false,[54,60,54,60]); }catch(e){}' +
    'var pendingMarker=null;' +
    'function showPending(lon,lat,name){' +
    '  try{' +
    '    if(pendingMarker){ pendingMarker.setPosition([lon,lat]); }' +
    '    else { pendingMarker=new AMap.Marker({position:[lon,lat],title:name||"待确认",' +
    '      icon:new AMap.Icon({size:new AMap.Size(28,28),imageSize:new AMap.Size(28,28),' +
    '        image:"data:image/svg+xml;charset=utf-8,"+encodeURIComponent(' +
    '          "<svg xmlns=\\"http://www.w3.org/2000/svg\\" width=\\"28\\" height=\\"28\\"><circle cx=\\"14\\" cy=\\"14\\" r=\\"10\\" fill=\\"#0A84FF\\" fill-opacity=\\"0.25\\" stroke=\\"#0A84FF\\" stroke-width=\\"3\\"/></svg>")' +
    '      }), offset:new AMap.Pixel(-14,-14)}); map.add(pendingMarker); }' +
    '  }catch(e){}' +
    '}' +
    'map.on("click",function(ev){' +
    '  if(PICK==="none"||!showChrome){ return; }' +
    '  var lon=ev.lnglat.getLng(), lat=ev.lnglat.getLat();' +
    '  map.setZoomAndCenter(Math.max(map.getZoom(),15),[lon,lat]);' +
    '  showPending(lon,lat,"地图选点");' +
    '  sendChoose(lon,lat,"地图选点");' +
    '  setHint("已选地点，请选择用途");' +
    '});' +
    'var bMe=document.getElementById("btnMe"); if(bMe) bMe.onclick=function(){ map.setZoomAndCenter(zoom,[cLon,cLat]); };' +
    'var bTr=document.getElementById("btnTr"); if(bTr) bTr.onclick=function(){ applyTraffic(!trafficOn); };' +
    'if(showChrome){ applyTraffic(showTraffic); setHint("轻点地图选点，或点下方位置搜索"); }' +
    'else { if(showTraffic){ try{ applyTraffic(true); }catch(e){} } }' +
    '})();</script></body></html>';
  return html;
}
