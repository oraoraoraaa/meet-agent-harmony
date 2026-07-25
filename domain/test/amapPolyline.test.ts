import assert from 'node:assert/strict';
import test from 'node:test';

import {
  decodeAmapPolyline,
  ensureEndpoints,
  mergePolylines,
  routePointsFromPolyline,
} from '../src/amapPolyline.ts';

test('decodeAmapPolyline parses semicolon lon,lat pairs', () => {
  const pts = decodeAmapPolyline('108.8905,34.2324;108.9000,34.2400;108.9465,34.2610');
  assert.equal(pts.length, 3);
  assert.ok(Math.abs(pts[0].lon - 108.8905) < 1e-9);
  assert.ok(Math.abs(pts[2].lat - 34.2610) < 1e-9);
});

test('decodeAmapPolyline ignores junk and empty', () => {
  assert.deepEqual(decodeAmapPolyline(''), []);
  assert.equal(decodeAmapPolyline('nope;108.9,34.2').length, 1);
});

test('mergePolylines drops duplicate joints', () => {
  const a = decodeAmapPolyline('1,1;2,2');
  const b = decodeAmapPolyline('2,2;3,3');
  const m = mergePolylines([a, b]);
  assert.equal(m.length, 3);
  assert.equal(m[1].lon, 2);
  assert.equal(m[2].lon, 3);
});

test('routePointsFromPolyline distributes duration by path distance', () => {
  const poly = decodeAmapPolyline('0,0;0,0.01;0,0.02');
  const route = routePointsFromPolyline(poly, 600);
  assert.equal(route.length, 3);
  assert.equal(route[0].driverSecs, 0);
  assert.ok(route[2].driverSecs > 590 && route[2].driverSecs <= 600);
  assert.ok(route[1].driverSecs > 200 && route[1].driverSecs < 400);
  assert.ok(route[1].metersFromStart > 0);
});

test('ensureEndpoints pins first/last to from/to', () => {
  const poly = decodeAmapPolyline('1,1;2,2;3,3');
  const fixed = ensureEndpoints(poly, { lon: 10, lat: 10 }, { lon: 20, lat: 20 });
  assert.equal(fixed[0].lon, 10);
  assert.equal(fixed[fixed.length - 1].lat, 20);
  assert.equal(fixed.length, 3);
});
