import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AppLanguage, AppSettings, LlmMode } from '../common/AppSettings';

const STORE_NAME = 'meet_agent_settings';

const KEY_MAP_API = 'mapApiKey';
const KEY_MAP_WEB = 'mapWebKey';
const KEY_LLM_BASE = 'llmBaseUrl';
const KEY_LLM_KEY = 'llmApiKey';
const KEY_LLM_MODEL = 'llmModel';
const KEY_PROXY = 'proxyBaseUrl';
const KEY_LLM_MODE = 'llmMode';
const KEY_LANG = 'language';
const KEY_FIXTURES = 'demoFixtures';
const KEY_TRACE = 'verboseAgentTrace';

function asLlmMode(raw: string): LlmMode {
  if (raw === 'user_key' || raw === 'proxy' || raw === 'offline') {
    return raw;
  }
  return 'offline';
}

function asLanguage(raw: string): AppLanguage {
  if (raw === 'en') {
    return 'en';
  }
  return 'zh-CN';
}

/**
 * Preferences-backed settings store (device-local).
 * Not cryptographically hardened vault — good enough for Phase 0 keys;
 * later can migrate sensitive fields to system secure storage APIs.
 */
export class SettingsStore {
  static async load(context: common.Context): Promise<AppSettings> {
    const store = await preferences.getPreferences(context, STORE_NAME);
    const settings = new AppSettings();
    settings.mapApiKey = await store.get(KEY_MAP_API, '') as string;
    settings.mapWebKey = await store.get(KEY_MAP_WEB, '') as string;
    settings.llmBaseUrl = await store.get(KEY_LLM_BASE, settings.llmBaseUrl) as string;
    settings.llmApiKey = await store.get(KEY_LLM_KEY, '') as string;
    settings.llmModel = await store.get(KEY_LLM_MODEL, settings.llmModel) as string;
    settings.proxyBaseUrl = await store.get(KEY_PROXY, settings.proxyBaseUrl) as string;
    settings.llmMode = asLlmMode(await store.get(KEY_LLM_MODE, 'offline') as string);
    settings.language = asLanguage(await store.get(KEY_LANG, 'zh-CN') as string);
    settings.demoFixtures = await store.get(KEY_FIXTURES, true) as boolean;
    settings.verboseAgentTrace = await store.get(KEY_TRACE, false) as boolean;
    return settings;
  }

  static async save(context: common.Context, settings: AppSettings): Promise<void> {
    const store = await preferences.getPreferences(context, STORE_NAME);
    await store.put(KEY_MAP_API, settings.mapApiKey);
    await store.put(KEY_MAP_WEB, settings.mapWebKey);
    await store.put(KEY_LLM_BASE, settings.llmBaseUrl);
    await store.put(KEY_LLM_KEY, settings.llmApiKey);
    await store.put(KEY_LLM_MODEL, settings.llmModel);
    await store.put(KEY_PROXY, settings.proxyBaseUrl);
    await store.put(KEY_LLM_MODE, settings.llmMode);
    await store.put(KEY_LANG, settings.language);
    await store.put(KEY_FIXTURES, settings.demoFixtures);
    await store.put(KEY_TRACE, settings.verboseAgentTrace);
    await store.flush();
  }
}
