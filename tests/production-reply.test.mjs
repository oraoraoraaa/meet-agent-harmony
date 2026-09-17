import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import test from 'node:test';

const root = new URL('../entry/src/main/ets/', import.meta.url);
const source = ['domain/Models.ets', 'services/agent/Grounding.ets', 'services/agent/OfflineReply.ets']
  .map(path => readFileSync(new URL(path, root), 'utf8')
    .replace(/^import\s[\s\S]*?;\n/gm, '').replace(/\bexport /g, '')).join('\n');
const context = vm.createContext({});
vm.runInContext(stripTypeScriptTypes(source) + '\nglobalThis.reply = buildOfflinePlanReply;', context);

test('production offline reply preserves grounded times and estimate label without internal IDs', () => {
  const rec = {
    dataSource: 'estimate',
    stayPut: { driverEtaMin: 17, recommended: false, rationale: '等待司机' },
    suggestions: [{ mode: 'walking', passengerEtaMin: 4, driverEtaMin: 9,
      completionMin: 9, driverSavedMin: 8, recommended: true, rationale: '步行后会合更快' }],
  };
  const reply = context.reply(rec);
  assert.match(reply, /估算/);
  for (const time of ['17', '4', '9', '8']) assert.ok(reply.includes(time + ' 分钟'));
  assert.match(reply, /步行后会合更快/);
  assert.doesNotMatch(reply, /stayPut|suggestion:|PLAN_ID|方案 ID|未调用大模型/);
});
