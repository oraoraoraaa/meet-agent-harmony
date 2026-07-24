/**
 * OpenAI-compatible chat completions client (Mode A user key / Mode B proxy).
 * Never logs API keys.
 *
 * ArkTS notes: prefer classes / typed DTOs; build request body as JSON string
 * to avoid arkts-no-untyped-obj-literals on nested maps.
 */

import { http } from '@kit.NetworkKit';
import {
  AppSettings,
  LLM_MODE_OFFLINE,
  LLM_MODE_PROXY,
  LLM_MODE_USER_KEY
} from '../../common/AppSettings';
import { ChatMessage, ROLE_ASSISTANT, ROLE_SYSTEM, ROLE_TOOL, ROLE_USER, ToolCall } from '../agent/AgentTypes';
import { DEFAULT_LLM_TEMPERATURE, DEFAULT_LLM_TIMEOUT_MS } from '../agent/Prompts';

export class LlmChatResult {
  content: string = '';
  toolCalls: ToolCall[] = [];
  finishReason: string = '';
  rawStatus: number = 0;
  error: string = '';
}

export class LlmPingResult {
  ok: boolean = false;
  message: string = '';
  latencyMs: number = 0;
}

class OpenAiEndpoint {
  baseUrl: string = '';
  apiKey: string = '';
  model: string = '';
}

function trimSlash(url: string): string {
  let u: string = url.trim();
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}

function resolveEndpoint(settings: AppSettings): OpenAiEndpoint | null {
  if (settings.llmMode === LLM_MODE_OFFLINE) {
    return null;
  }
  if (settings.llmMode === LLM_MODE_PROXY) {
    const base: string = trimSlash(settings.proxyBaseUrl);
    if (base.length === 0) {
      return null;
    }
    const ep: OpenAiEndpoint = new OpenAiEndpoint();
    ep.baseUrl = base;
    ep.apiKey = '';
    ep.model = settings.llmModel.trim().length > 0 ? settings.llmModel.trim() : 'deepseek-chat';
    return ep;
  }
  if (settings.llmMode !== LLM_MODE_USER_KEY) {
    // unknown mode → treat as offline unless configured as user key
  }
  const base: string = trimSlash(settings.llmBaseUrl);
  const key: string = settings.llmApiKey.trim();
  if (base.length === 0 || key.length === 0) {
    return null;
  }
  const ep: OpenAiEndpoint = new OpenAiEndpoint();
  ep.baseUrl = base;
  ep.apiKey = key;
  ep.model = settings.llmModel.trim().length > 0 ? settings.llmModel.trim() : 'deepseek-chat';
  return ep;
}

function chatCompletionsUrl(baseUrl: string): string {
  if (baseUrl.endsWith('/chat/completions')) {
    return baseUrl;
  }
  if (baseUrl.endsWith('/v1')) {
    return `${baseUrl}/chat/completions`;
  }
  return `${baseUrl}/v1/chat/completions`;
}

function jsonEscape(s: string): string {
  let out: string = '';
  for (let i = 0; i < s.length; i++) {
    const ch: string = s.charAt(i);
    const code: number = s.charCodeAt(i);
    if (ch === '\\') {
      out += '\\\\';
    } else if (ch === '"') {
      out += '\\"';
    } else if (ch === '\n') {
      out += '\\n';
    } else if (ch === '\r') {
      out += '\\r';
    } else if (ch === '\t') {
      out += '\\t';
    } else if (code < 0x20) {
      // skip other control chars
    } else {
      out += ch;
    }
  }
  return out;
}

function messageToJsonString(m: ChatMessage): string {
  let s: string = '{';
  s += `"role":"${jsonEscape(m.role)}"`;
  s += `,"content":"${jsonEscape(m.content)}"`;
  if (m.role === ROLE_TOOL && m.toolCallId.length > 0) {
    s += `,"tool_call_id":"${jsonEscape(m.toolCallId)}"`;
  }
  if (m.name.length > 0) {
    s += `,"name":"${jsonEscape(m.name)}"`;
  }
  if (m.role === ROLE_ASSISTANT && m.toolCalls.length > 0) {
    s += ',"tool_calls":[';
    for (let i = 0; i < m.toolCalls.length; i++) {
      if (i > 0) {
        s += ',';
      }
      const tc: ToolCall = m.toolCalls[i];
      // argumentsJson is already a JSON object/string payload from the model
      let argsRaw: string = tc.argumentsJson.length > 0 ? tc.argumentsJson : '{}';
      // If model gave a JSON object string, embed as JSON string value (OpenAI wire format).
      s += `{"id":"${jsonEscape(tc.id)}","type":"function","function":{"name":"${jsonEscape(tc.name)}","arguments":"${jsonEscape(argsRaw)}"}}`;
    }
    s += ']';
  }
  s += '}';
  return s;
}

function buildChatBody(
  model: string,
  messages: ChatMessage[],
  toolsJsonArray: string,
  temperature: number,
  maxTokens: number
): string {
  let s: string = '{';
  s += `"model":"${jsonEscape(model)}"`;
  s += `,"temperature":${temperature}`;
  s += `,"max_tokens":${maxTokens}`;
  s += ',"messages":[';
  for (let i = 0; i < messages.length; i++) {
    if (i > 0) {
      s += ',';
    }
    s += messageToJsonString(messages[i]);
  }
  s += ']';
  if (toolsJsonArray.length > 2) {
    s += `,"tools":${toolsJsonArray}`;
    s += ',"tool_choice":"auto"';
  }
  s += '}';
  return s;
}

function asRecord(raw: Object): Record<string, Object> | null {
  if (raw === null || typeof raw !== 'object') {
    return null;
  }
  return raw as Record<string, Object>;
}

function parseToolCalls(raw: Object | undefined): ToolCall[] {
  const out: ToolCall[] = [];
  if (raw === undefined || raw === null) {
    return out;
  }
  if (!(raw instanceof Array)) {
    return out;
  }
  const arr: Object[] = raw as Object[];
  for (let i = 0; i < arr.length; i++) {
    const itemRec: Record<string, Object> | null = asRecord(arr[i]);
    if (itemRec === null) {
      continue;
    }
    const tc: ToolCall = new ToolCall();
    const idVal: Object | undefined = itemRec['id'];
    if (typeof idVal === 'string') {
      tc.id = idVal as string;
    } else {
      tc.id = `call_${i}`;
    }
    const fnObj: Object | undefined = itemRec['function'];
    const fnRec: Record<string, Object> | null = fnObj !== undefined ? asRecord(fnObj) : null;
    if (fnRec !== null) {
      const nameVal: Object | undefined = fnRec['name'];
      const argsVal: Object | undefined = fnRec['arguments'];
      if (typeof nameVal === 'string') {
        tc.name = nameVal as string;
      }
      if (typeof argsVal === 'string') {
        tc.argumentsJson = argsVal as string;
      } else if (argsVal !== undefined && argsVal !== null) {
        try {
          tc.argumentsJson = JSON.stringify(argsVal);
        } catch (e) {
          const _ignored: Object = e as Object;
          tc.argumentsJson = '{}';
        }
      } else {
        tc.argumentsJson = '{}';
      }
    }
    if (tc.name.length > 0) {
      out.push(tc);
    }
  }
  return out;
}

export class OpenAiCompatibleClient {
  private settings: AppSettings;
  private timeoutMs: number;
  private cancelled: boolean = false;

  constructor(settings: AppSettings, timeoutMs: number = DEFAULT_LLM_TIMEOUT_MS) {
    this.settings = settings;
    this.timeoutMs = timeoutMs;
  }

  cancel(): void {
    this.cancelled = true;
  }

  isAvailable(): boolean {
    return resolveEndpoint(this.settings) !== null && this.settings.llmConfigured();
  }

  async ping(): Promise<LlmPingResult> {
    const result: LlmPingResult = new LlmPingResult();
    const ep: OpenAiEndpoint | null = resolveEndpoint(this.settings);
    if (ep === null) {
      result.ok = false;
      result.message = '未配置 LLM（离线或缺少 Base URL / Key）';
      return result;
    }
    const t0: number = Date.now();
    const msgs: ChatMessage[] = [];
    const sys: ChatMessage = new ChatMessage();
    sys.role = ROLE_SYSTEM;
    sys.content = 'Reply with the single word pong.';
    const user: ChatMessage = new ChatMessage();
    user.role = ROLE_USER;
    user.content = 'ping';
    msgs.push(sys);
    msgs.push(user);
    const chat: LlmChatResult = await this.chat(msgs, '[]', 0.0, 8);
    result.latencyMs = Date.now() - t0;
    if (chat.error.length > 0) {
      result.ok = false;
      result.message = chat.error;
      return result;
    }
    result.ok = true;
    result.message = `连接成功 · ${result.latencyMs} ms · 模型 ${ep.model}`;
    return result;
  }

  /**
   * @param toolsJsonArray OpenAI tools array as JSON text, e.g. "[]" or buildOpenAiToolsJsonString().
   */
  async chat(
    messages: ChatMessage[],
    toolsJsonArray: string = '[]',
    temperature: number = DEFAULT_LLM_TEMPERATURE,
    maxTokens: number = 1024
  ): Promise<LlmChatResult> {
    const out: LlmChatResult = new LlmChatResult();
    if (this.cancelled) {
      out.error = '已取消';
      return out;
    }
    const ep: OpenAiEndpoint | null = resolveEndpoint(this.settings);
    if (ep === null) {
      out.error = 'LLM 未配置';
      return out;
    }

    const url: string = chatCompletionsUrl(ep.baseUrl);
    const bodyStr: string = buildChatBody(ep.model, messages, toolsJsonArray, temperature, maxTokens);

    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const header: Record<string, string> = {};
      header['Content-Type'] = 'application/json';
      if (ep.apiKey.length > 0) {
        header['Authorization'] = `Bearer ${ep.apiKey}`;
      }

      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: bodyStr,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: this.timeoutMs,
        readTimeout: this.timeoutMs
      });

      out.rawStatus = response.responseCode;
      const raw: string = typeof response.result === 'string' ? response.result as string : `${response.result}`;

      if (response.responseCode < 200 || response.responseCode >= 300) {
        const snippet: string = raw.length > 180 ? raw.substring(0, 180) + '…' : raw;
        out.error = `LLM HTTP ${response.responseCode}: ${snippet}`;
        return out;
      }

      let parsedObj: Object;
      try {
        parsedObj = JSON.parse(raw) as Object;
      } catch (e) {
        const _ignored: Object = e as Object;
        out.error = 'LLM 响应不是合法 JSON';
        return out;
      }
      const parsed: Record<string, Object> | null = asRecord(parsedObj);
      if (parsed === null) {
        out.error = 'LLM 响应格式错误';
        return out;
      }

      const choicesVal: Object | undefined = parsed['choices'];
      if (!(choicesVal instanceof Array) || (choicesVal as Object[]).length === 0) {
        out.error = 'LLM 响应缺少 choices';
        return out;
      }
      const firstRec: Record<string, Object> | null = asRecord((choicesVal as Object[])[0]);
      if (firstRec === null) {
        out.error = 'LLM 响应 choice 无效';
        return out;
      }
      const finish: Object | undefined = firstRec['finish_reason'];
      if (typeof finish === 'string') {
        out.finishReason = finish as string;
      }
      const messageVal: Object | undefined = firstRec['message'];
      const message: Record<string, Object> | null =
        messageVal !== undefined ? asRecord(messageVal) : null;
      if (message === null) {
        out.error = 'LLM 响应缺少 message';
        return out;
      }
      const contentVal: Object | undefined = message['content'];
      if (typeof contentVal === 'string') {
        out.content = contentVal as string;
      } else if (contentVal === null || contentVal === undefined) {
        out.content = '';
      } else {
        out.content = `${contentVal}`;
      }
      out.toolCalls = parseToolCalls(message['tool_calls']);
      return out;
    } catch (e) {
      const errObj: Object = e as Object;
      out.error = `LLM 请求失败: ${errObj}`;
      return out;
    } finally {
      try {
        httpRequest.destroy();
      } catch (e2) {
        const _ignored2: Object = e2 as Object;
      }
    }
  }
}

export function llmAvailable(settings: AppSettings): boolean {
  return settings.llmConfigured() && resolveEndpoint(settings) !== null;
}
