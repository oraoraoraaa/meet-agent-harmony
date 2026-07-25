/**
 * Build self-contained HTML for interactive AMap JS map (GCJ-02).
 * Key injected at runtime from preferences — never commit real keys.
 * Picks: meetagent://pick?role=driver|passenger&lon=&lat=&name=
 *
 * Features vs prototype:
 *  - live traffic layer (AMap.TileLayer.Traffic)
 *  - dual role: 司机起点 / 乘客位置 (tap + search both)
 *  - drag/zoom, recenter, POI search
 */

export class MapViewMarkers {
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
   * Home: search/路况/居中 chrome.
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
    'body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;overflow:hidden;}' +
    '#top{position:absolute;left:8px;right:8px;top:8px;z-index:30;display:flex;flex-direction:column;gap:6px;}' +
    (showChrome ? '' : '#top,#list,#hint{display:none!important;}') +
    '#roles{display:none;}' +
    '.role{flex:1;height:32px;border:1px solid rgba(255,255,255,.22);border-radius:10px;' +
    'background:rgba(18,24,36,.9);color:#d9e6ff;font-size:12px;}' +
    '.role.on{background:#0A84FF;color:#fff;border-color:#59a8ff;font-weight:600;}' +
    '.role:disabled{opacity:.45;}' +
    '#bar{display:flex;gap:6px;}' +
    '#q{flex:1;height:36px;border-radius:18px;border:1px solid rgba(0,0,0,.08);' +
    'background:rgba(255,255,255,.96);color:#1c1c1e;padding:0 12px;font-size:13px;box-shadow:0 2px 10px rgba(0,0,0,.08);}' +
    '#btn,#btnMe,#btnTr{height:36px;border:0;border-radius:18px;padding:0 12px;font-size:12px;' +
    'background:#0A84FF;color:#fff;box-shadow:0 2px 8px rgba(10,132,255,.25);}' +
    '#btnMe{background:#3A4A5C;box-shadow:none;}' +
    '#btnTr{background:#34C759;min-width:52px;}' +
    '#btnTr.off{background:#8E8E93;}' +
    '#hint{position:absolute;left:8px;right:8px;bottom:8px;z-index:30;color:#1c1c1e;' +
    'font-size:11px;background:rgba(255,255,255,.88);padding:7px 9px;border-radius:12px;line-height:1.35;' +
    'box-shadow:0 2px 12px rgba(0,0,0,.12);}' +
    '#list{position:absolute;left:8px;right:8px;top:56px;z-index:31;max-height:170px;overflow:auto;' +
    'display:none;background:rgba(255,255,255,.98);border-radius:14px;padding:8px;box-shadow:0 8px 24px rgba(0,0,0,.14);}' +
    '#list.open{display:block;}' +
    '#listHead{display:flex;align-items:center;justify-content:space-between;margin-bottom:6px;}' +
    '#listTitle{font-size:12px;color:#3a3a3c;font-weight:600;}' +
    '#listClose{border:0;background:#F2F2F7;color:#1c1c1e;border-radius:14px;height:28px;padding:0 12px;font-size:12px;}' +
    '.hit{background:#F8F9FB;color:#1c1c1e;padding:10px;border-radius:12px;margin-bottom:6px;' +
    'border:1px solid rgba(0,0,0,.06);font-size:12px;}' +
    '.hit b{color:#0A84FF;}' +
    '.lbl{display:none;}' +
    '.lbl-d{background:#0A84FF;}.lbl-p{background:#34C759;}' +
    '</style>' +
    (hasKey
      ? '<script src="https://webapi.amap.com/maps?v=2.0&key=' + keyEsc + '&plugin=AMap.PlaceSearch,AMap.Geocoder"></script>'
      : '') +
    '</head><body>' +
    '<div id="top">' +
    (allowSwitch
      ? '<div id="roles">' +
        '<button type="button" class="role" id="roleD">司机起点</button>' +
        '<button type="button" class="role" id="roleP">乘客位置</button>' +
        '</div>'
      : '') +
    '<div id="bar">' +
    '<input id="q" placeholder="' + (hasKey ? '搜索地点 / 地址 / POI' : '无 Key · 点击地图选点') + '"/>' +
    '<button id="btn" type="button">搜索</button>' +
    '<button id="btnTr" type="button" class="">路况</button>' +
    '<button id="btnMe" type="button">居中</button>' +
    '</div></div>' +
    '<div id="list"><div id="listHead"><span id="listTitle">搜索结果</span>' +
    '<button type="button" id="listClose">关闭</button></div><div id="listBody"></div></div>' +
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
    'var showTraffic=' + showTraffic + ';' +
    'var allowSwitch=' + allowSwitch + ';' +
    'var showChrome=' + showChrome + ';' +
    'var trafficOn=!!showTraffic;' +
    'function setHint(t){ var h=document.getElementById("hint"); if(h) h.textContent=t; }' +
    'function setListOpen(on){ var el=document.getElementById("list"); if(!el) return; el.className=on?"open":""; }' +
    'function clearList(){ var body=document.getElementById("listBody"); if(body) body.innerHTML=""; setListOpen(false); }' +
    'function roleLabel(){ return "地点"; }' +
    'function syncRoleUi(){ var q=document.getElementById("q"); if(q){ q.placeholder="搜索地点 / 地址 / POI"; } }' +
    'function sendChoose(lon,lat,name){' +
    '  if(PICK==="none") return;' +
    '  var u="meetagent://choose?lon="+encodeURIComponent(String(lon))' +
    '    +"&lat="+encodeURIComponent(String(lat))' +
    '    +"&name="+encodeURIComponent(name||"");' +
    '  try{ window.location.href=u; }catch(e){}' +
    '}' +
    'function sendPick(lon,lat,name,role){' +
    '  var r=role||""; if(!r||r==="none"){ sendChoose(lon,lat,name); return; }' +
    '  var u="meetagent://pick?role="+encodeURIComponent(r)' +
    '    +"&lon="+encodeURIComponent(String(lon))' +
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
    '    canvas.style.width=W+"px"; canvas.style.height=H+"px"; draw(); }' +
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
    '      ctx.fillStyle="#fff"; ctx.font="10px sans-serif"; ctx.fillText(label,p.x+10,p.y+3); }' +
    '    if(hasD) mark(dLon,dLat,"#0A84FF","司"); if(hasP) mark(pLon,pLat,"#34C759","乘"); }' +
    '  var dragging=false,lx=0,ly=0;' +
    '  canvas.addEventListener("touchstart",function(e){ dragging=true; lx=e.touches[0].clientX; ly=e.touches[0].clientY; });' +
    '  canvas.addEventListener("touchmove",function(e){ if(!dragging) return; var x=e.touches[0].clientX,y=e.touches[0].clientY;' +
    '    ox-=(x-lx)/scale; oy+=(y-ly)/scale; lx=x; ly=y; draw(); e.preventDefault(); },{passive:false});' +
    '  canvas.addEventListener("touchend",function(){ dragging=false; });' +
    '  canvas.addEventListener("click",function(e){ if(PICK==="none"||!showChrome) return; var r=canvas.getBoundingClientRect();' +
    '    var p=unproj(e.clientX-r.left,e.clientY-r.top);' +
    '    sendChoose(p.lon,p.lat,"地图选点"); setHint("已选点，请选择用途 "+p.lat.toFixed(5)+","+p.lon.toFixed(5)); });' +
    '  var elMe=document.getElementById("btnMe"); if(elMe) elMe.onclick=function(){ ox=cLon; oy=cLat; draw(); };' +
    '  var elBtn=document.getElementById("btn"); if(elBtn) elBtn.onclick=function(){ setHint("无 Map Web Key：仅支持点击选点"); };' +
    '  var elTr=document.getElementById("btnTr"); if(elTr) elTr.onclick=function(){ setHint("无 Key：无法加载实时路况"); };' +
    '  var elClose=document.getElementById("listClose"); if(elClose) elClose.onclick=function(){ clearList(); setHint("已关闭搜索"); };' +
    '  if(showChrome) syncRoleUi(); window.addEventListener("resize",resize); resize();' +
    '  if(showChrome) setHint("示意地图 · 搜索或点选地点后选择用途"); return;' +
    '}' +
    // —— AMap live ——
    'var map=new AMap.Map("map",{zoom:zoom,center:[cLon,cLat],viewMode:"2D",' +
    '  mapStyle:"amap://styles/whitesmoke",showBuildingBlock:false,features:["bg","road","point"]});' +
    'var trafficLayer=null;' +
    'function applyTraffic(on){' +
    '  trafficOn=!!on;' +
    '  var b=document.getElementById("btnTr");' +
    '  if(b){ b.className=trafficOn?"":"off"; b.textContent=trafficOn?"路况":"路况关"; }' +
    '  try{' +
    '    if(trafficOn){' +
    '      if(!trafficLayer){ trafficLayer=new AMap.TileLayer.Traffic({zIndex:10,autoRefresh:true,interval:180}); }' +
    '      map.add(trafficLayer);' +
    '      setHint("实时路况 · 搜索地点后选择用途");' +
    '    } else if(trafficLayer){ map.remove(trafficLayer); setHint("路况已关 · 搜索地点后选择用途"); }' +
    '  }catch(e){ setHint("路况图层不可用（检查 JS Key 路况权限）"); }' +
    '}' +
    'var dMarker=null,pMarker=null,dLine=null,pLine=null;' +
    'function pinSvg(color,label){' +
    '  var svg="<svg xmlns=\\"http://www.w3.org/2000/svg\\" width=\\"36\\" height=\\"48\\" viewBox=\\"0 0 36 48\\">' +
    '<defs><filter id=\\"s\\" x=\\"-20%\\" y=\\"-10%\\" width=\\"140%\\" height=\\"140%\\"><feDropShadow dx=\\"0\\" dy=\\"2\\" stdDeviation=\\"2\\" flood-opacity=\\"0.35\\"/></filter></defs>' +
    '<path filter=\\"url(#s)\\" fill=\\""+color+"\\" d=\\"M18 0C9 0 2 7 2 16c0 12 16 32 16 32s16-20 16-32C34 7 27 0 18 0z\\"/>' +
    '<circle cx=\\"18\\" cy=\\"16\\" r=\\"7\\" fill=\\"#fff\\"/>' +
    '<text x=\\"18\\" y=\\"20\\" text-anchor=\\"middle\\" font-size=\\"10\\" font-family=\\"sans-serif\\" fill=\\""+color+"\\" font-weight=\\"700\\">"+label+"</text></svg>";' +
    '  return "data:image/svg+xml;charset=utf-8,"+encodeURIComponent(svg);' +
    '}' +
    'function ensureDriver(lon,lat,name){' +
    '  if(dMarker){ dMarker.setPosition([lon,lat]); if(name) dMarker.setTitle(name); }' +
    '  else { dMarker=new AMap.Marker({position:[lon,lat],title:name||"司机",' +
    '    icon:new AMap.Icon({size:new AMap.Size(36,48),imageSize:new AMap.Size(36,48),image:pinSvg("#0A84FF","司")}),' +
    '    offset:new AMap.Pixel(-18,-46)}); map.add(dMarker); }' +
    '  dLon=lon; dLat=lat; hasD=1;' +
    '}' +
    'function ensurePassenger(lon,lat,name){' +
    '  if(pMarker){ pMarker.setPosition([lon,lat]); if(name) pMarker.setTitle(name); }' +
    '  else { pMarker=new AMap.Marker({position:[lon,lat],title:name||"乘客",' +
    '    icon:new AMap.Icon({size:new AMap.Size(36,48),imageSize:new AMap.Size(36,48),image:pinSvg("#34C759","乘")}),' +
    '    offset:new AMap.Pixel(-18,-46)}); map.add(pMarker); }' +
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
    '    setHint("针点已更新");' +
    '  }catch(e){ setHint("针点更新失败"); }' +
    '};' +
    'if(hasD) ensureDriver(dLon,dLat,"司机"); if(hasP) ensurePassenger(pLon,pLat,"乘客");' +
    'if(dPoly && dPoly.length>=2){ dLine=new AMap.Polyline({path:dPoly.map(function(x){return [x[0],x[1]];}),' +
    '  strokeColor:"#0A84FF",strokeWeight:6,strokeOpacity:.95,zIndex:50}); map.add(dLine); }' +
    'if(pPoly && pPoly.length>=2){ pLine=new AMap.Polyline({path:pPoly.map(function(x){return [x[0],x[1]];}),' +
    '  strokeColor:"#34C759",strokeWeight:5,strokeOpacity:.95,strokeStyle:"dashed",zIndex:50}); map.add(pLine); }' +
    'try{ var fit=[]; if(hasD) fit.push([dLon,dLat]); if(hasP) fit.push([pLon,pLat]);' +
    '  if(dPoly) dPoly.forEach(function(x){fit.push([x[0],x[1]]);});' +
    '  if(pPoly) pPoly.forEach(function(x){fit.push([x[0],x[1]]);});' +
    '  if(fit.length>=2) map.setFitView(null,false,[48,48,48,48]); }catch(e){}' +
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
    '  setHint("已选点，请选择用途 "+lat.toFixed(5)+", "+lon.toFixed(5));' +
    '});' +
    'var bMe=document.getElementById("btnMe"); if(bMe) bMe.onclick=function(){ map.setZoomAndCenter(zoom,[cLon,cLat]); };' +
    'var bTr=document.getElementById("btnTr"); if(bTr) bTr.onclick=function(){ applyTraffic(!trafficOn); };' +
    'var bClose=document.getElementById("listClose"); if(bClose) bClose.onclick=function(){ clearList(); setHint("已关闭搜索"); };' +
    'var bSearch=document.getElementById("btn"); if(bSearch) bSearch.onclick=function(){' +
    '  if(PICK==="none"||!showChrome){ return; }' +
    '  var q=(document.getElementById("q").value||"").trim(); if(!q){ setHint("请输入关键词"); return; }' +
    '  setHint("搜索中…");' +
    '  var body=document.getElementById("listBody"); if(body) body.innerHTML=""; setListOpen(true);' +
    '  var center=map.getCenter();' +
    '  var loc=center.getLng()+","+center.getLat();' +
    '  var url="https://restapi.amap.com/v3/place/text?key="+encodeURIComponent(KEY)' +
    '    +"&keywords="+encodeURIComponent(q)+"&offset=10&page=1&extensions=base"' +
    '    +"&location="+encodeURIComponent(loc)+"&radius=8000&sortrule=distance";' +
    '  fetch(url).then(function(r){return r.json();}).then(function(j){' +
    '    if(String(j.status)!=="1"){ setHint("搜索失败: "+(j.info||"检查 Place 权限")); setListOpen(false); return; }' +
    '    var pois=j.pois||[]; var listBody=document.getElementById("listBody"); if(!listBody) return; listBody.innerHTML="";' +
    '    if(!pois.length){ setHint("无结果"); setListOpen(false); return; }' +
    '    setHint("找到 "+pois.length+" 个 · 点选后选择用途"); setListOpen(true);' +
    '    pois.forEach(function(poi){' +
    '      var loc2=(poi.location||"").split(","); if(loc2.length<2) return;' +
    '      var lon=parseFloat(loc2[0]), lat=parseFloat(loc2[1]); if(isNaN(lon)||isNaN(lat)) return;' +
    '      var div=document.createElement("div"); div.className="hit";' +
    '      div.innerHTML="<b>地点</b> "+(poi.name||"")+" · "+(poi.address||"");' +
    '      div.onclick=function(){' +
    '        map.setZoomAndCenter(16,[lon,lat]);' +
    '        showPending(lon,lat,poi.name||"POI");' +
    '        sendChoose(lon,lat,poi.name||"POI"); clearList();' +
    '        setHint("已选地点 · 请选择用途 · "+(poi.name||""));' +
    '      }; listBody.appendChild(div);' +
    '    });' +
    '  }).catch(function(){ setHint("搜索网络失败"); setListOpen(false); });' +
    '};' +
    'if(showChrome){ syncRoleUi(); applyTraffic(showTraffic); setHint("搜索地点后选择用途 · 路况可开关"); }' +
    'else { if(showTraffic){ try{ applyTraffic(true); }catch(e){} } }' +
    '})();</script></body></html>';
  return html;
}

export function polyToJsonPairs(pointsLonLat: number[][]): string {
  let s: string = '[';
  for (let i = 0; i < pointsLonLat.length; i++) {
    if (i > 0) {
      s += ',';
    }
    s += '[' + pointsLonLat[i][0] + ',' + pointsLonLat[i][1] + ']';
  }
  s += ']';
  return s;
}
