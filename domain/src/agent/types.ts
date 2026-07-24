/**
 * Portable agent contracts (pure TS).
 * ArkTS mirror lives under entry/src/main/ets/services/agent/.
 */

import type { RecommendationSet, Scenario } from '../models.ts';

export type AgentRole = 'system' | 'user' | 'assistant' | 'tool';

export interface ChatMessage {
  readonly role: AgentRole;
  readonly content: string;
  readonly name?: string;
  readonly toolCallId?: string;
  /** OpenAI-style tool calls on assistant messages. */
  readonly toolCalls?: readonly ToolCall[];
}

export interface ToolCall {
  readonly id: string;
  readonly name: string;
  readonly argumentsJson: string;
}

export interface ToolDefinition {
  readonly name: string;
  readonly description: string;
  /** JSON Schema object (serializable). */
  readonly parameters: Record<string, unknown>;
}

export interface ToolTraceEntry {
  readonly name: string;
  readonly ok: boolean;
  readonly durationMs: number;
  readonly summary: string;
  readonly error?: string;
}

export interface AgentTurnResult {
  readonly replyText: string;
  readonly recommendation: RecommendationSet | null;
  /** Grounded plan id: stayPut | suggestion:N | empty. */
  readonly selectedPlanId: string;
  readonly toolTrace: readonly ToolTraceEntry[];
  readonly usedLlm: boolean;
  readonly offlineFallback: boolean;
  readonly error?: string;
}

export interface AgentSessionSnapshot {
  readonly scenario: Scenario;
  readonly lastRecommendation: RecommendationSet | null;
}
