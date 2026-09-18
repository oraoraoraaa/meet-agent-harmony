import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import test from 'node:test';

const source = readFileSync(new URL('../entry/src/main/ets/services/agent/AgentOrchestrator.ets', import.meta.url), 'utf8')
  .replace(/^import\s[\s\S]*?;\n/gm, '').replace(/\bexport /g, '');
test('progress follows actual LLM and tool calls, with no raw arguments or reasoning', async () => {
  const events = [];
  let calls = 0;
  const c = vm.createContext({
    llmAvailable: () => true,
    AgentSessionState: class {}, ChatMessage: class {},
    OpenAiCompatibleClient: class { async chat() {
      events.push('request');
      return ++calls === 1 ? { error: '', content: '', toolCalls: [{ name: 'get_driving_route', argumentsJson: 'private', id: '1' }] }
        : { error: '', content: 'done', toolCalls: [] };
    } },
    AgentToolHost: class { async dispatch() { events.push('dispatch'); return {trace: {}, contentJson: '{}'}; } },
    buildOpenAiToolsJsonString: () => '[]',
    ROLE_SYSTEM:'system', ROLE_USER:'user', ROLE_ASSISTANT:'assistant', ROLE_TOOL:'tool',
    MEET_AGENT_SYSTEM_PROMPT:'', DEFAULT_LLM_TEMPERATURE:0.2, DEFAULT_MAX_TOOL_ITERS:6,
  });
  vm.runInContext(stripTypeScriptTypes(source) + '\nglobalThis.Orch = AgentOrchestrator;', c);
  const orch = new c.Orch({}, {city:'西安', driver:{name:'a',lon:1,lat:2}, passenger:{name:'b',lon:3,lat:4}}, {});
  orch.onProgress = message => events.push(message);
  orch.finalize = async () => ({});
  await orch.handleUserTurn('test');
  assert.deepEqual(events, ['助手正在分析出行需求…','request','正在获取驾车路线与路况…','dispatch','助手正在整理会合建议…','request']);
  orch.cancelled = true;
  orch.progress('late');
  assert.ok(!events.includes('late'));
});
