/**
 * Agent contracts — ArkTS mirror of domain/src/agent (classes for ArkTS friendliness).
 */

import { RecommendationSet, Scenario } from '../../domain/Models';

export type AgentRole = string;

export const ROLE_SYSTEM: AgentRole = 'system';
export const ROLE_USER: AgentRole = 'user';
export const ROLE_ASSISTANT: AgentRole = 'assistant';
export const ROLE_TOOL: AgentRole = 'tool';

export class ToolCall {
  id: string = '';
  name: string = '';
  argumentsJson: string = '';
}

export class ChatMessage {
  role: AgentRole = ROLE_USER;
  content: string = '';
  name: string = '';
  toolCallId: string = '';
  toolCalls: ToolCall[] = [];
}

export class ToolTraceEntry {
  name: string = '';
  ok: boolean = true;
  durationMs: number = 0;
  summary: string = '';
  error: string = '';
}

export class AgentTurnResult {
  replyText: string = '';
  recommendation: RecommendationSet | null = null;
  selectedPlanId: string = '';
  toolTrace: ToolTraceEntry[] = [];
  usedLlm: boolean = false;
  offlineFallback: boolean = false;
  error: string = '';
}

export class AgentSessionState {
  scenario: Scenario = new Scenario();
  lastRecommendation: RecommendationSet | null = null;
}
