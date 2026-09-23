import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import test from 'node:test';

const source = readFileSync(new URL('../entry/src/main/ets/common/AiDisclosure.ets', import.meta.url), 'utf8').replace(/\bexport /g, '');
const context = vm.createContext({});
vm.runInContext(stripTypeScriptTypes(source) + '\nglobalThis.copy = labeledAiCopy;', context);
test('AI copy retains explicit attribution and full response, including multiline text', () => {
  const body = '建议先核实道路通行情况。\n步行约 4 分钟。';
  const copied = context.copy(body);
  assert.ok(copied.startsWith('【人工智能生成内容 · MeetAgent接驾优化】\n'));
  assert.ok(copied.includes(body));
  assert.ok(copied.endsWith('转发时请保留本标识。'));
});
