/**
 * Bounded tool-using agent orchestrator.
 * Mode C offline when LLM unavailable; falls back to engine on LLM errors.
 */

import { AppSettings } from '../../common/AppSettings';
import { RecommendationSet, Scenario } from '../../domain/Models';
import { MapProvider, PlanningService } from '../map/MapProvider';
import { llmAvailable, LlmChatResult, OpenAiCompatibleClient } from '../llm/OpenAiCompatibleClient';
import {
  AgentSessionState,
  AgentTurnResult,
  ChatMessage,
  ROLE_ASSISTANT,
  ROLE_SYSTEM,
  ROLE_TOOL,
  ROLE_USER,
  ToolCall,
  ToolTraceEntry
} from './AgentTypes';
import {
  extractPlanIdFromText,
  GroundingResult,
  resolveGroundedSelection,
  validateOrFallbackPlanId
} from './Grounding';
import { buildOfflinePlanReply } from './OfflineReply';
import { DEFAULT_LLM_TEMPERATURE, DEFAULT_MAX_TOOL_ITERS, MEET_AGENT_SYSTEM_PROMPT } from './Prompts';
import { AgentToolHost, buildOpenAiToolsJsonString, TOOL_GENERATE_AND_SCORE, ToolDispatchResult } from './ToolHost';

export class AgentOrchestrator {
  private settings: AppSettings;
  private session: AgentSessionState;
  private provider: MapProvider;
  private client: OpenAiCompatibleClient | null = null;
  private cancelled: boolean = false;

  constructor(settings: AppSettings, scenario: Scenario, provider: MapProvider) {
    this.settings = settings;
    this.session = new AgentSessionState();
    this.session.scenario = scenario;
    this.provider = provider;
    if (llmAvailable(settings)) {
      this.client = new OpenAiCompatibleClient(settings);
    }
  }

  cancel(): void {
    this.cancelled = true;
    if (this.client !== null) {
      this.client.cancel();
    }
  }

  getSession(): AgentSessionState {
    return this.session;
  }

  updateScenario(scenario: Scenario): void {
    this.session.scenario = scenario;
  }

  async handleUserTurn(userText: string, maxToolIters: number = DEFAULT_MAX_TOOL_ITERS): Promise<AgentTurnResult> {
    this.cancelled = false;
    if (!llmAvailable(this.settings) || this.client === null) {
      return this.runOffline();
    }
    try {
      return await this.runLlmLoop(userText, maxToolIters);
    } catch (e) {
      const errObj: Object = e as Object;
      const offline: AgentTurnResult = await this.runOffline();
      offline.error = `${errObj}`;
      offline.replyText = `大模型调用异常，已回退本地引擎。\n\n${offline.replyText}`;
      offline.offlineFallback = true;
      return offline;
    }
  }

  private async runOffline(): Promise<AgentTurnResult> {
    const result: AgentTurnResult = new AgentTurnResult();
    result.usedLlm = false;
    result.offlineFallback = true;
    const host: AgentToolHost = new AgentToolHost(this.session, this.provider);
    const t0: number = Date.now();
    try {
      const disp: ToolDispatchResult = await host.dispatch(TOOL_GENERATE_AND_SCORE, '{}');
      result.toolTrace.push(disp.trace);
      result.recommendation = this.session.lastRecommendation;
      if (result.recommendation !== null) {
        result.selectedPlanId = resolveGroundedSelection('', result.recommendation);
        result.replyText = buildOfflinePlanReply(result.recommendation);
      } else {
        result.replyText = '本地规划未返回结果，请检查起终点。';
        result.error = 'empty_recommendation';
      }
    } catch (e) {
      const errObj: Object = e as Object;
      result.error = `${errObj}`;
      result.replyText = `本地规划失败：${errObj}`;
      const tr: ToolTraceEntry = new ToolTraceEntry();
      tr.name = TOOL_GENERATE_AND_SCORE;
      tr.ok = false;
      tr.durationMs = Date.now() - t0;
      tr.summary = 'engine error';
      tr.error = `${errObj}`;
      result.toolTrace.push(tr);
    }
    return result;
  }

  private async runLlmLoop(userText: string, maxToolIters: number): Promise<AgentTurnResult> {
    const host: AgentToolHost = new AgentToolHost(this.session, this.provider);
    const toolsJson: string = buildOpenAiToolsJsonString();
    const messages: ChatMessage[] = [];

    const sys: ChatMessage = new ChatMessage();
    sys.role = ROLE_SYSTEM;
    sys.content = MEET_AGENT_SYSTEM_PROMPT;
    messages.push(sys);

    const scenarioHint: ChatMessage = new ChatMessage();
    scenarioHint.role = ROLE_SYSTEM;
    scenarioHint.content =
      `场景城市：${this.session.scenario.city.length > 0 ? this.session.scenario.city : '未设置'}；` +
        `司机「${this.session.scenario.driver.name}」` +
        `(${this.session.scenario.driver.lon.toFixed(4)}, ${this.session.scenario.driver.lat.toFixed(4)})；` +
        `乘客「${this.session.scenario.passenger.name}」` +
        `(${this.session.scenario.passenger.lon.toFixed(4)}, ${this.session.scenario.passenger.lat.toFixed(4)})。` +
        '请先用工具确认约束并 generate_and_score_plans。数值以工具为准。';
    messages.push(scenarioHint);

    const user: ChatMessage = new ChatMessage();
    user.role = ROLE_USER;
    user.content = userText;
    messages.push(user);

    const trace: ToolTraceEntry[] = [];
    const client: OpenAiCompatibleClient = this.client as OpenAiCompatibleClient;

    for (let iter = 0; iter < maxToolIters; iter++) {
      if (this.cancelled) {
        const cancelled: AgentTurnResult = await this.runOffline();
        cancelled.error = 'cancelled';
        cancelled.replyText = '已取消。\n\n' + cancelled.replyText;
        return cancelled;
      }

      const resp: LlmChatResult = await client.chat(messages, toolsJson, DEFAULT_LLM_TEMPERATURE, 1200);
      if (resp.error.length > 0) {
        const offline: AgentTurnResult = await this.runOffline();
        offline.error = resp.error;
        offline.replyText = `大模型不可用（${resp.error}），已用本地引擎。\n\n${offline.replyText}`;
        offline.offlineFallback = true;
        for (let t = 0; t < offline.toolTrace.length; t++) {
          trace.push(offline.toolTrace[t]);
        }
        offline.toolTrace = trace;
        return offline;
      }

      if (resp.toolCalls.length > 0) {
        const asst: ChatMessage = new ChatMessage();
        asst.role = ROLE_ASSISTANT;
        asst.content = resp.content;
        asst.toolCalls = resp.toolCalls;
        messages.push(asst);

        for (let i = 0; i < resp.toolCalls.length; i++) {
          const call: ToolCall = resp.toolCalls[i];
          const disp: ToolDispatchResult = await host.dispatch(call.name, call.argumentsJson);
          trace.push(disp.trace);
          const toolMsg: ChatMessage = new ChatMessage();
          toolMsg.role = ROLE_TOOL;
          toolMsg.toolCallId = call.id;
          toolMsg.name = call.name;
          toolMsg.content = disp.contentJson;
          messages.push(toolMsg);
        }
        continue;
      }

      const text: string = resp.content.length > 0 ? resp.content : '已完成规划，请查看方案卡片。';
      return await this.finalize(text, trace, true);
    }

    const offline: AgentTurnResult = await this.runOffline();
    offline.replyText = `工具调用次数已达上限，改用本地引擎结果。\n\n${offline.replyText}`;
    offline.offlineFallback = true;
    for (let t = 0; t < offline.toolTrace.length; t++) {
      trace.push(offline.toolTrace[t]);
    }
    offline.toolTrace = trace;
    return offline;
  }

  private async finalize(
    replyText: string,
    trace: ToolTraceEntry[],
    usedLlm: boolean
  ): Promise<AgentTurnResult> {
    const result: AgentTurnResult = new AgentTurnResult();
    result.usedLlm = usedLlm;
    result.offlineFallback = false;
    result.toolTrace = trace;

    if (this.session.lastRecommendation === null) {
      try {
        const rec: RecommendationSet = await PlanningService.plan(this.session.scenario, this.provider);
        this.session.lastRecommendation = rec;
        const tr: ToolTraceEntry = new ToolTraceEntry();
        tr.name = TOOL_GENERATE_AND_SCORE;
        tr.ok = true;
        tr.durationMs = 0;
        tr.summary = 'auto engine after LLM without tool';
        result.toolTrace.push(tr);
      } catch (e) {
        const errObj: Object = e as Object;
        result.replyText = replyText + `\n\n（自动规划失败：${errObj}）`;
        result.selectedPlanId = '';
        result.recommendation = null;
        return result;
      }
    }

    result.recommendation = this.session.lastRecommendation;
    const claimed: string = extractPlanIdFromText(replyText);
    const grounded: GroundingResult = validateOrFallbackPlanId(claimed, result.recommendation);
    result.selectedPlanId = grounded.planId;
    if (grounded.rejectedHallucination) {
      result.replyText =
        replyText +
          `\n\n（系统校验：无效方案 ID「${claimed}」，已回退引擎推荐 ${grounded.planId}。）`;
    } else {
      result.replyText = replyText;
    }
    return result;
  }
}
